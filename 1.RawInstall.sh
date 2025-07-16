#!/bin/bash -e

echo -e "______  $LINENO  ____  Set default build variables.  ____________________________________________\n"

. $(dirname $(readlink -f $0))/?.*.env

echo -e "______  $LINENO  ____  Install local packages required to build target.  ________________________\n"

apt -y install xfsprogs binutils debootstrap qemu-user-static

echo -e "______  $LINENO  ____  Format destination disk / directory.  ____________________________________\n"

rm -rf $WorkDir
mkdir -p $WorkDir

echo -e "______  $LINENO  ____  Get additional files required for install.  ______________________________\n"

(  [ -d $FromBase/Files ] || mkdir $FromBase/Files
   cd $FromBase/Files
   for Each in $(awk '/^cp \$FromBase\/Files\//{print $2}' $FromBase/[0-9].*.sh); do
      if [ ! -f "${Each##*/}" ]; then
         wget -nv https://github.com/Chris-Scot/embarm/raw/refs/heads/main/${Each#*/}
      fi
   done )

echo -e "______  $LINENO  ____  Copy repository cache for quicker building.  _____________________________\n"

[ -d $FromBase/Cache.${ProcArch}/apt ] || mkdir -p $FromBase/Cache.${ProcArch}/apt

echo -e "______  $LINENO  ____  Download and prepare debian install.  ____________________________________\n"

mkdir -p $WorkDir/var/cache
echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) -> $(find $WorkDir/var/cache/apt | wc -l)"; cp -rn $FromBase/Cache.${ProcArch}/apt $WorkDir/var/cache/
#	The --excluded stuff is included in busybox.
debootstrap --foreign --arch $RepoArch --variant=minbase --include=$CoreInclude --exclude=$CoreExclude $CoreVersion $WorkDir http://ftp.uk.debian.org/debian

cp /usr/bin/qemu-${ProcArch}-static $WorkDir/
mkdir -p $WorkDir/etc/apt/apt.conf.d/
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > $WorkDir/etc/apt/apt.conf.d/90cache

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $WorkDir/var/cache/apt | wc -l)"; cp -r $WorkDir/var/cache/apt $FromBase/Cache.${ProcArch}/

LANG=C.UTF-8 chroot $WorkDir /qemu-${ProcArch}-static /bin/sh /debootstrap/debootstrap --second-stage

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $WorkDir/var/cache/apt | wc -l)"; cp -r $WorkDir/var/cache/apt $FromBase/Cache.${ProcArch}/

echo -e "______  $LINENO  ____  Install a kernel into the target filesystem.  ____________________________\n"

################################################################################
LANG=C.UTF-8 chroot $WorkDir /qemu-${ProcArch}-static /bin/sh << EOInstall

if [ "${KernelVersion:0:11}" != "linux-image"  ]; then
   KernelVersion=\$(apt list | grep "linux-image-6.*[0-9]$KernelVersion-$RepoArch/"|sort|tail -1)
   KernelVersion=\${KernelVersion%%/*}
fi
apt -y install \$KernelVersion

EOInstall
################################################################################

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $WorkDir/var/cache/apt | wc -l)"; cp -r $WorkDir/var/cache/apt $FromBase/Cache.${ProcArch}/

echo -e "______  $LINENO  ____  Shift things about for the boot process.  ________________________________\n"

ln -s /lib/systemd/systemd $WorkDir/sbin/init
 
(  cd $WorkDir/boot
   ln -s $(ls -1 vmlinuz-*) vmlinuz
   ln -s $(ls -1 initrd.*) initrd  )

cat << EOInstall > $WorkDir/boot/grub.cfg
set timeout=4
set default=Raw

menuentry 'Raw' --id 'Raw' {
  linux (\$dev)/$ImageTag/boot/vmlinuz ImageTag=$ImageTag boot=mountroot
  initrd (\$dev)/$ImageTag/boot/initrd (\$dev)/$ImageTag/boot/initroot
}

menuentry 'OracleCloud' --id 'OracleCloud' {
  configfile \$prefix/grub.cfg.std
}
EOInstall

[ -d $WorkDir/boot/scripts ] || mkdir $WorkDir/boot/scripts
cp $FromBase/Files/mountroot $WorkDir/boot/scripts/
(  cd $WorkDir/boot
   echo scripts/mountroot | cpio -oH newc | gzip > initroot
   rm -rf scripts  
)

cp $FromBase/Files/init $WorkDir/boot/

mkdir $WorkDir/boot/lib
cp $WorkDir/lib/modules/*/kernel/fs/squashfs/squashfs.ko $WorkDir/boot/lib/
cp $WorkDir/lib/modules/*/kernel/fs/overlayfs/overlay.ko $WorkDir/boot/lib/

echo -e "______  $LINENO  ____  Make the network run nicely.  ___________________________________________\n"

cp $FromBase/Files/20-wired.network $WorkDir/etc/systemd/network/

################################################################################
LANG=C.UTF-8 chroot $WorkDir /qemu-${ProcArch}-static /bin/sh << 'EOInstall'

systemctl enable systemd-networkd

EOInstall
################################################################################

echo -e "______  $LINENO  ____  Tamper with the installation to make it work well with Oracle.  __________\n"

echo "$ImageTag" > $WorkDir/etc/hostname
cat << EOInstall > $WorkDir/etc/hosts
127.0.0.1${Tab}localhost.localdomain${Tab}localhost
EOInstall

cp $FromBase/Files/adjtime $WorkDir/etc/
cp $FromBase/Files/rc.local $WorkDir/etc/
cp $FromBase/Files/keyboard $WorkDir/etc/default/
cp $FromBase/Files/AutoMount.sh $WorkDir/usr/local/sbin/
cp $FromBase/Files/SnapAll.sh $WorkDir/usr/local/sbin/
cp $FromBase/Files/SnapExpire.sh $WorkDir/usr/local/sbin/
cp $FromBase/Files/lsoverlay $WorkDir/usr/local/sbin/
cp $FromBase/Files/PathEnv.sh $WorkDir/etc/profile.d/
chmod 755 $WorkDir/usr/local/sbin/* $WorkDir/etc/rc.local

rm $WorkDir/etc/resolv.conf
ln -fs /etc/machine-id $WorkDir/var/lib/dbus/machine-id
:> $WorkDir/etc/machine-id

echo 'DROPBEAR_EXTRA_ARGS="-ws"' >> $WorkDir/etc/default/dropbear

ln -s systemctl $WorkDir/usr/bin/halt
ln -s systemctl $WorkDir/usr/bin/poweroff
ln -s systemctl $WorkDir/usr/bin/reboot
ln -s systemctl $WorkDir/usr/bin/shutdown

################################################################################
LANG=C.UTF-8 chroot $WorkDir /qemu-${ProcArch}-static /bin/sh << EOInstall

cd /usr/local/bin
for Each in \$(busybox --list | grep -v busybox); do
   which \$Each || ln -fs /usr/bin/busybox \$Each
done

rm -rf /dev/*
rm -rf /run/*

chmod 0 /proc
chmod 0 /sys
chmod 0 /run
chmod 0 /tmp
 
mkdir -pm1730 /var/spool/cron/crontabs
crontab - << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin


15  00   *   *   *      SnapAll.sh > /var/log/SnapAll.log 2>&1
00  02   *   *   *      SnapExpire.sh > /var/log/SnapExpire.log 2>&1
00   *   *   *   *      ntpdate pool.ntp.org > /var/log/ntpdate.log 2>&1
EOF

useradd -mUG adm,systemd-journal -s /bin/bash opc -u 1000
echo "%opc	ALL=(ALL)	NOPASSWD: ALL" > /etc/sudoers

passwd << EOF
$ImageTag
$ImageTag
EOF

EOInstall
################################################################################

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $WorkDir/var/cache/apt | wc -l)"; cp -r $WorkDir/var/cache/apt $FromBase/Cache.${ProcArch}/

echo -e "______  $LINENO  ____  Clean up random files after installing $ImageTag.  _______________________\n"

rm $WorkDir/initrd.img
rm $WorkDir/initrd.img.old
rm $WorkDir/qemu-${ProcArch}-static
rm $WorkDir/vmlinuz
rm $WorkDir/vmlinuz.old
rm $WorkDir/etc/apt/apt.conf.d/90cache
rm -rf $WorkDir/var/cache/*

echo -e "______  $LINENO  ____  Create a tar for easy upload.  ___________________________________________\n"

cd $ToBase
rm -f ${ImageTag}.tgz
tar -zcSf ${ImageTag}.tgz $ImageTag

echo "All is said and done.  Thusly, there is nothing more to say or do."
