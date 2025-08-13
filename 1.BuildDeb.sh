#!/bin/bash -e

echo -e "______  $LINENO  ____  Set default build variables.  ____________________________________________\n"

. $(dirname $(readlink -f $0))/?.*.env

echo -e "______  $LINENO  ____  Install local packages required to build target.  ________________________\n"

apt -y install binutils debootstrap qemu-user-static squashfs-tools xfsprogs

echo -e "______  $LINENO  ____  Format destination disk / directory.  ____________________________________\n"

rm -rf $ToBase
mkdir -p $ToBase

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
mkdir -p $ToBase/Core/var/cache
mkdir -p $ToBase/Core/etc/apt/apt.conf.d
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > $ToBase/Core/etc/apt/apt.conf.d/90cache
echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) -> $(find $ToBase/Core/var/cache/apt | wc -l)"; cp -rn $FromBase/Cache.${ProcArch}/apt $ToBase/Core/var/cache/

#	This makes the network connect during the build.
cp /etc/resolv.conf $ToBase/Core/etc/

echo -e "______  $LINENO  ____  Download and prepare debian install.  ____________________________________\n"

#	The --excluded stuff is included in busybox.
debootstrap --foreign --arch $RepoArch --variant=minbase --include=$CoreInclude --exclude=$CoreExclude $CoreVersion $ToBase/Core http://ftp.uk.debian.org/debian

cp /usr/bin/qemu-${ProcArch}-static $ToBase/Core/

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $ToBase/Core/var/cache/apt | wc -l)"; cp -r $ToBase/Core/var/cache/apt $FromBase/Cache.${ProcArch}/

LANG=C.UTF-8 chroot $ToBase/Core /qemu-${ProcArch}-static /bin/sh /debootstrap/debootstrap --second-stage

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $ToBase/Core/var/cache/apt | wc -l)"; cp -r $ToBase/Core/var/cache/apt $FromBase/Cache.${ProcArch}/

echo -e "______  $LINENO  ____  Install a kernel into the target filesystem.  ____________________________\n"

#	Shove in my custom rootmount script which will be included in the initramfs update.
mkdir -p $ToBase/Core/etc/initramfs-tools/scripts/
cp $FromBase/Files/local $ToBase/Core/etc/initramfs-tools/scripts/

################################################################################
LANG=C.UTF-8 chroot $ToBase/Core /qemu-${ProcArch}-static /bin/sh << EOInstall

apt update

if [ "${KernelVersion:0:11}" != "linux-image"  ]; then
   KernelVersion=\$(apt list | grep "linux-image-6.*[0-9]$KernelVersion-$RepoArch/"|sort|tail -1)
   KernelVersion=\${KernelVersion%%/*}
fi
apt -y install \$KernelVersion

EOInstall
################################################################################

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $ToBase/Core/var/cache/apt | wc -l)"; cp -r $ToBase/Core/var/cache/apt $FromBase/Cache.${ProcArch}/

echo -e "______  $LINENO  ____  Make the network run nicely.  ___________________________________________\n"

cp $FromBase/Files/20-wired.network $ToBase/Core/etc/systemd/network/
cp $FromBase/Files/20-ipvlan.network $ToBase/Core/etc/systemd/network/
cp $FromBase/Files/20-macvlan.network $ToBase/Core/etc/systemd/network/

echo -e "______  $LINENO  ____  Tamper with the installation to make it work well with Oracle.  __________\n"

echo "$ImageTag" > $ToBase/Core/etc/hostname
cat << EOInstall > $ToBase/Core/etc/hosts
127.0.0.1${Tab}localhost.localdomain${Tab}localhost
EOInstall

cp $FromBase/Files/adjtime $ToBase/Core/etc/
cp $FromBase/Files/rc.local $ToBase/Core/etc/
cp $FromBase/Files/keyboard $ToBase/Core/etc/default/
cp $FromBase/Files/PathEnv.sh $ToBase/Core/etc/profile.d/
cp $FromBase/Files/AutoMount.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/SnapAll.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/SnapExpire.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/lsoverlay $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/DiffFirm $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/Firm2Squash $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/SaveFirm $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/AutoForward.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/MachineDelete.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/MachineStart.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/MachineStop.sh $ToBase/Core/usr/local/sbin/

chmod 755 $ToBase/Core/usr/local/sbin/* $ToBase/Core/etc/rc.local

ln -fs /etc/machine-id $ToBase/Core/var/lib/dbus/machine:1-id
:> $ToBase/Core/etc/machine-id

echo 'DROPBEAR_EXTRA_ARGS="-ws"' >> $ToBase/Core/etc/default/dropbear

ln -s systemctl $ToBase/Core/usr/bin/halt
ln -s systemctl $ToBase/Core/usr/bin/poweroff
ln -s systemctl $ToBase/Core/usr/bin/reboot
ln -s systemctl $ToBase/Core/usr/bin/shutdown

echo -e "______  $LINENO  ____  Add the extra packages defined in MoreInstall.  __________________________\n"

################################################################################
LANG=C.UTF-8 chroot $ToBase/Core /qemu-${ProcArch}-static /bin/sh << EOInstall

apt -y install $MoreInstall

setcap 'cap_net_bind_service=+ep' /usr/bin/stunnel4

systemctl enable systemd-networkd

rm -rf /dev/*
rm -rf /run/*

chmod 0 /dev
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

PATH=/usr/local/sbin:/usr/sbin:/usr/bin
cd /usr/local/bin
for Each in \$(busybox --list | grep -v busybox); do
   which \$Each || ln -fs /usr/bin/busybox \$Each
done

EOInstall
################################################################################

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $ToBase/Core/var/cache/apt | wc -l)"; cp -r $ToBase/Core/var/cache/apt $FromBase/Cache.${ProcArch}/

echo -e "______  $LINENO  ____  Build filesystem for Cloud or BareMetal.  ________________________________\n"
if [ -d $ToBase/Core/etc/cloud ]; then
   cp $FromBase/Files/cloud.cfg $ToBase/Core/etc/cloud/cloud.cfg
   sed -i 's/--network-veth /--network-macvlan=enp0s6 /' $ToBase/Core/usr/lib/systemd/system/systemd-nspawn\@.service
else
   sed -i 's/--network-veth /--network-macvlan=ens3 /' $ToBase/Core/usr/lib/systemd/system/systemd-nspawn\@.service
fi

echo -e "______  $LINENO  ____  Build filesystem for 05-Desktop.  ________________________________________\n"

cp $FromBase/Files/KyaeolOS.jpg $ToBase/Core/usr/share/images/fluxbox/
echo "session.screen0.workspaces: 1" >> $ToBase/Core/etc/X11/fluxbox/init
echo "session.screen0.toolbar.height: 32" >> $ToBase/Core/etc/X11/fluxbox/init
sed -i '/^background.pixmap: /c\background.pixmap:\t/usr/share/images/fluxbox/KyaeolOS.jpg' $ToBase/Core/usr/share/fluxbox/styles/Squared_for_Debian/theme.cfg

echo -e "______  $LINENO  ____  Build filesystem for 10-XPRA.  ___________________________________________\n"

rm $ToBase/Core/etc/xpra/*.pem
cp $FromBase/Files/stunnel.conf $ToBase/Core/etc/stunnel/
cp $FromBase/Files/StartProxy.sh $ToBase/Core/usr/local/sbin/
cp $FromBase/Files/StartXPRA.sh $ToBase/Core/usr/local/bin/
chmod 755 $ToBase/Core/usr/local/sbin/*
chmod 755 $ToBase/Core/usr/local/bin/*

echo -e "______  $LINENO  ____  Create filesystem for RootRO.  ___________________________________________\n"

truncate $ToBase/RootRO.xfs -s 10G
mkfs.xfs -L RootRO $ToBase/RootRO.xfs
sync
mount -v $ToBase/RootRO.xfs /mnt
mkdir -p /mnt/root /mnt/home/opc/.ssh /mnt/etc/default /mnt/usr/local
chmod -R 700 /mnt/root /mnt/home/opc
if [ -f $FromBase/Files/authorized_keys ]; then
   cp $FromBase/Files/authorized_keys /mnt/home/opc/.ssh/
   chmod 600 /mnt/home/opc/.ssh/authorized_keys
fi
chown -R 1000:1000 /mnt/home/opc
echo "$ImageTag" > /mnt/etc/hostname
mv $ToBase/Core/etc/resolv.conf /mnt/etc/
mv $ToBase/Core/usr/local/sbin /mnt/usr/local/sbin/
mv $ToBase/Core/etc/default/keyboard /mnt/etc/default/

cat << EOInstall > /mnt/etc/hosts
127.0.0.1${Tab}localhost.localdomain${Tab}localhost
127.0.0.1${Tab}$ImageTag.localdomain${Tab}$ImageTag
EOInstall
umount -v /mnt

echo -e "______  $LINENO  ____  Create filesystem for RootRW.  ___________________________________________\n"

truncate $ToBase/RootRW.xfs -s 10G
mkfs.xfs -L RootRW $ToBase/RootRW.xfs
sync
mount -v $ToBase/RootRW.xfs /mnt
mkdir /mnt/WorkDir /mnt/UpperDir
umount -v /mnt

#	echo -e "______  $LINENO  ____  Shift things about for the boot process.  ________________________________\n"

mv $ToBase/Core/boot $ToBase/
mkdir -m0 $ToBase/Core/boot

echo -e "______  $LINENO  ____  Clean up random files.  __________________________________________________\n"

rm $ToBase/Core/qemu-${ProcArch}-static
rm $ToBase/Core/initrd.img
rm $ToBase/Core/initrd.img.old
rm $ToBase/Core/vmlinuz
rm $ToBase/Core/vmlinuz.old
rm $ToBase/Core/etc/apt/apt.conf.d/90cache
rm -rf $ToBase/Core/var/cache/*

echo -e "______  $LINENO  ____  Convert filesystems to SquashFS.  ________________________________________\n"

mksquashfs $ToBase/Core "$ToBase/Core.sq" -comp xz -b 1M -always-use-fragments -noappend

echo -e "______  $LINENO  ____  Install things for the boot process.  ____________________________________\n"

cp /usr/bin/qemu-${ProcArch}-static $ToBase/Core/
cp /etc/resolv.conf $ToBase/Core/etc/

################################################################################
LANG=C.UTF-8 chroot $ToBase/Core /qemu-${ProcArch}-static /bin/sh << 'EOInstall'

apt -y install systemd-boot extlinux

EOInstall
################################################################################

mkdir $ToBase/boot/lib
cp $ToBase/Core/lib/modules/*/kernel/fs/squashfs/squashfs.ko $ToBase/boot/lib/
cp $ToBase/Core/lib/modules/*/kernel/fs/overlayfs/overlay.ko $ToBase/boot/lib/
cp $FromBase/Files/init $ToBase/boot/

echo -e "______  $LINENO  ____  Configure EFI boot installation.  ________________________________________\n"

mkdir -p "$ToBase/boot/EFI/Boot" "$ToBase/boot/loader/entries"
EFIFile=$(ls -1 $ToBase/Core/usr/lib/systemd/boot/efi/systemd-boot*.efi)
cp $EFIFile "$ToBase/boot/EFI/Boot/${EFIFile##*-}"

(  cd $ToBase/boot
   ln -s $(ls -1 vmlinuz-*) vmlinuz
   ln -s $(ls -1 initrd.*) initrd
   cp vmlinuz EFI/Boot/
   cp initrd EFI/Boot  )

cat << EOInstall > $ToBase/boot/loader/loader.conf
timeout 5
default Any
EOInstall

cat << EOInstall > $ToBase/boot/loader/entries/Any.conf
title Any
linux /EFI/Boot/vmlinuz
options initrd=/EFI/Boot/initrd
EOInstall

cat << EOInstall > $ToBase/boot/loader/entries/Run.conf
title Run
linux /EFI/Boot/vmlinuz
options initrd=/EFI/Boot/initrd ImageTag=$ImageTag
EOInstall

cat << EOInstall > $ToBase/boot/loader/entries/Fresh.conf
title Fresh
linux /EFI/Boot/vmlinuz
options initrd=/EFI/Boot/initrd ImageTag=$ImageTag RootRO=RootRO
EOInstall

cat << EOInstall > $ToBase/boot/loader/entries/Resume.conf
title Resume
linux /EFI/Boot/vmlinuz
options initrd=/EFI/Boot/initrd ImageTag=$ImageTag RootRO=RootRO RootRW=RootRW
EOInstall

echo    "#############################################################################################"
echo    "#       To boot EFI, move EFI & loader directories to the root of your EFI partition.  eg.  #"
echo mv $ToBase/boot/EFI /media/sda1/
echo mv $ToBase/boot/loader /media/sda1/
echo    "#       Ensure this is the correct (EFI) partition type and formatted correctly (FAT).      #"
echo    "#############################################################################################"

echo -e "______  $LINENO  ____  Configure EXTLinux boot installation.  ___________________________________\n"

cp $ToBase/Core/usr/bin/extlinux $ToBase/boot/extlinux.x64
cp $ToBase/Core/usr/lib/syslinux/modules/bios/ldlinux.c32 $ToBase/boot/
cp $ToBase/Core/usr/lib/syslinux/modules/bios/libcom32.c32 $ToBase/boot/
cp $ToBase/Core/usr/lib/syslinux/modules/bios/libutil.c32 $ToBase/boot/
cp $ToBase/Core/usr/lib/EXTLINUX/mbr.bin $ToBase/boot/
cp $ToBase/Core/usr/lib/syslinux/modules/bios/vesamenu.c32 $ToBase/boot/

cat << EOInstall > $ToBase/boot/syslinux.cfg
UI /$ImageTag/boot/vesamenu.c32
PROMPT 0
TIMEOUT 50
DEFAULT Any

LABEL Any
MENU LABEL $ImageTag (Any)
KERNEL /$ImageTag/boot/vmlinuz
APPEND initrd=/$ImageTag/boot/initrd

LABEL Run
MENU LABEL $ImageTag (Run)
KERNEL /$ImageTag/boot/vmlinuz
APPEND initrd=/$ImageTag/boot/initrd ImageTag=$ImageTag

LABEL Fresh
MENU LABEL $ImageTag (Fresh)
KERNEL /$ImageTag/boot/vmlinuz
APPEND initrd=/$ImageTag/boot/initrd ImageTag=$ImageTag RootRO=RootRO

LABEL Resume
MENU LABEL $ImageTag (Resume)
KERNEL /$ImageTag/boot/vmlinuz
APPEND initrd=/$ImageTag/boot/initrd ImageTag=$ImageTag RootRO=RootRO RootRW=RootRW
EOInstall

echo    "#############################################################################################"
echo    "#       To boot EXTLinux, move the installation directory to the new boot partition.        #"
echo mv $ToBase /media/sda1
echo    "#       Then perform the following commands on the new boot partition.                      #"
echo /media/sda1/$ImageTag/boot/extlinux.x64 -i /media/sda1/$ImageTag/boot
echo dd bs=$(stat -c%s /media/sda1/$ImageTag/boot/mbr.bin) count=1 conv=notrunc if="/media/sda1/$ImageTag/boot/mbr.bin" of="/dev/sda"
echo    "#       Ensure your installation drive is marked for boot.  Recommended format is XFS.      #"
echo    "#############################################################################################"

echo -e "______  $LINENO  ____  Configure EXTLinux boot installation.  ___________________________________\n"

cat << EOInstall > $ToBase/boot/grub.cfg
set timeout=5
set default=Any

menuentry 'Any' --id 'Any' {
  linux (\$dev)/$ImageTag/boot/vmlinuz
  initrd (\$dev)/$ImageTag/boot/initrd
}

menuentry 'Run' --id 'Run' {
  linux (\$dev)/$ImageTag/boot/vmlinuz ImageTag=$ImageTag
  initrd (\$dev)/$ImageTag/boot/initrd
}

menuentry 'Fresh' --id 'Fresh' {
  linux (\$dev)/$ImageTag/boot/vmlinuz ImageTag=$ImageTag RootRO=RootRO
  initrd (\$dev)/$ImageTag/boot/initrd
}

menuentry 'Resume' --id 'Resume' {
  linux (\$dev)/$ImageTag/boot/vmlinuz ImageTag=$ImageTag RootRO=RootRO RootRW=RootRW
  initrd (\$dev)/$ImageTag/boot/initrd
}

menuentry 'OracleCloud' --id 'OracleCloud' {
  configfile \$prefix/grub.cfg.std
}
EOInstall

echo    "#############################################################################################"
echo    "#       To boot using an existing grub installation, replace grub.conf.                     #"
echo    "#############################################################################################"

echo -e "______  $LINENO  ____  Create a tar for easy upload.  ___________________________________________\n"

rm -rf $ToBase/Core
cd ${ToBase%/*}
tar -cSf ${ImageTag}.tar $ImageTag

echo "All is said and done.  Thusly, there is nothing more to say or do."
