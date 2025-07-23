#!/bin/bash -e

echo -e "______  $LINENO  ____  Set default build variables.  ____________________________________________\n"

. $(dirname $(readlink -f $0))/?.*.env

echo -e "______  $LINENO  ____  Do a real dodgy self mount.  _____________________________________________\n"

mount -v $WorkDir/Run.xfs $WorkDir

echo -e "______  $LINENO  ____  Copy repository cache for quicker building.  _____________________________\n"

[ -d $FromBase/Cache.${ProcArch}/apt ] || mkdir -p $FromBase/Cache.${ProcArch}/apt
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > $WorkDir/etc/apt/apt.conf.d/90cache
echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) -> $(find $WorkDir/var/cache/apt | wc -l)"; cp -rn $FromBase/Cache.${ProcArch}/apt $WorkDir/var/cache/

cp /usr/bin/qemu-${ProcArch}-static $WorkDir/
cp /etc/resolv.conf $WorkDir/etc/

echo -e "______  $LINENO  ____  Reconfigure as an overlay /  squashfs system.  ___________________________\n"

################################################################################
LANG=C.UTF-8 chroot $WorkDir /qemu-${ProcArch}-static /bin/sh << 'EOInstall'

apt -y install $MoreInstall

setcap 'cap_net_bind_service=+ep' /usr/bin/stunnel4

PATH=/usr/local/sbin:/usr/sbin:/usr/bin
cd /usr/local/bin
for Each in $(ls -1); do
   if which $Each; then
      rm $Each
   fi
done

EOInstall
################################################################################

echo "Cache $(find $FromBase/Cache.${ProcArch}/apt | wc -l) <- $(find $WorkDir/var/cache/apt | wc -l)"; cp -r $WorkDir/var/cache/apt $FromBase/Cache.${ProcArch}/
rm -rf $WorkDir/var/cache/*

cp $FromBase/Files/DiffFirm $WorkDir/usr/local/sbin/
cp $FromBase/Files/Firm2Squash $WorkDir/usr/local/sbin/
cp $FromBase/Files/SaveFirm $WorkDir/usr/local/sbin/

cp $FromBase/Files/AutoForward.sh $WorkDir/usr/local/sbin/

cp $FromBase/Files/MachineDelete.sh $WorkDir/usr/local/sbin/
cp $FromBase/Files/MachineStart.sh $WorkDir/usr/local/sbin/
cp $FromBase/Files/MachineStop.sh $WorkDir/usr/local/sbin/

if [ -d $WorkDir/etc/cloud ]; then
   echo -e "______  $LINENO  ____  Build filesystem for 02-Cloud-init.  _____________________________________\n"

   cp $FromBase/Files/cloud.cfg $WorkDir/etc/cloud/cloud.cfg
fi

echo -e "______  $LINENO  ____  Build filesystem for 03-Container.  ______________________________________\n"
  
if [ -d $WorkDir/etc/cloud ]; then
   sed -i 's/--network-veth /--network-macvlan=enp0s6 /' $WorkDir/usr/lib/systemd/system/systemd-nspawn\@.service
else
   sed -i 's/--network-veth /--network-macvlan=ens3 /' $WorkDir/usr/lib/systemd/system/systemd-nspawn\@.service
fi

echo -e "______  $LINENO  ____  Build filesystem for 05-Desktop.  ________________________________________\n"

cp $FromBase/Files/KyaeolOS.jpg $WorkDir/usr/share/images/fluxbox/
echo "session.screen0.workspaces: 1" >> $WorkDir/etc/X11/fluxbox/init
echo "session.screen0.toolbar.height: 32" >> $WorkDir/etc/X11/fluxbox/init
sed -i '/^background.pixmap: /c\background.pixmap:\t/usr/share/images/fluxbox/KyaeolOS.jpg' $WorkDir/usr/share/fluxbox/styles/Squared_for_Debian/theme.cfg

echo -e "______  $LINENO  ____  Build filesystem for 10-XPRA.  ___________________________________________\n"

rm $WorkDir/etc/xpra/*.pem
cp $FromBase/Files/stunnel.conf $WorkDir/etc/stunnel/
cp $FromBase/Files/StartProxy.sh $WorkDir/usr/local/sbin/
cp $FromBase/Files/StartXPRA.sh $WorkDir/usr/local/bin/
chmod 755 $WorkDir/usr/local/sbin/*
chmod 755 $WorkDir/usr/local/bin/*

echo -e "______  $LINENO  ____  Clean up random files after installing $ImageTag.  _______________________\n"

rm $WorkDir/qemu-${ProcArch}-static
rm $WorkDir/etc/apt/apt.conf.d/90cache
rm -rf $WorkDir/var/cache/apt

echo -e "______  $LINENO  ____  Create filesystem for HostFirm.  _________________________________________\n"

truncate $WorkDir.Run.xfs -s 10G
mkfs.xfs -L Run $WorkDir.Run.xfs
sync
mount -v $WorkDir.Run.xfs /mnt
mkdir -p /mnt/root /mnt/home/opc /mnt/etc/default /mnt/usr/local
chmod 700 /mnt/root /mnt/home/opc
chown 1000:1000 /mnt/home/opc
echo "$ImageTag" > /mnt/etc/hostname
mv $WorkDir/etc/resolv.conf /mnt/etc/
mv $WorkDir/usr/local/sbin /mnt/usr/local/sbin/
mv $WorkDir/etc/default/keyboard /mnt/etc/default/

cat << EOInstall > /mnt/etc/hosts
127.0.0.1${Tab}localhost.localdomain${Tab}localhost
127.0.0.1${Tab}$ImageTag.localdomain${Tab}$ImageTag
EOInstall
umount -v /mnt

echo -e "______  $LINENO  ____  Create Core xfs filesystem for $ImageTag.  _______________________________\n"

truncate $WorkDir.Core.xfs -s 10G
mkfs.xfs -L ${ImageTag%%.*} $WorkDir.Core.xfs
sync
mount -v $WorkDir.Core.xfs /mnt
mv $WorkDir/* /mnt/
umount -v /mnt
umount -v $WorkDir
mv $WorkDir.Core.xfs $WorkDir/Core.xfs
mv $WorkDir.Run.xfs $WorkDir/Run.xfs

truncate $WorkDir/Resume.xfs -s 10G
mkfs.xfs -L Resume $WorkDir/Resume.xfs
sync
mount -v $WorkDir/Resume.xfs /mnt
mkdir /mnt/WorkDir /mnt/UpperDir
umount -v /mnt

cat << EOInstall > $WorkDir/boot/grub.cfg
set timeout=4
set default=Run

menuentry 'Run' --id 'Run' {
  linux (\$dev)/$ImageTag/boot/vmlinuz ImageTag=$ImageTag RootRO=Run boot=mountroot
  initrd (\$dev)/$ImageTag/boot/initrd (\$dev)/$ImageTag/boot/initroot
}

menuentry 'Resume' --id 'Resume' {
  linux (\$dev)/$ImageTag/boot/vmlinuz ImageTag=$ImageTag RootRO=Run RootRW=Resume boot=mountroot
  initrd (\$dev)/$ImageTag/boot/initrd (\$dev)/$ImageTag/boot/initroot
}

menuentry 'OracleCloud' --id 'OracleCloud' {
  configfile \$prefix/grub.cfg.std
}
EOInstall

echo -e "______  $LINENO  ____  Create a tar for easy upload.  ___________________________________________\n"

cd $ToBase
rm -f ${ImageTag}.tgz
tar -zcSf ${ImageTag}.tgz $ImageTag

echo "All is said and done.  Thusly, there is nothing more to say or do."
