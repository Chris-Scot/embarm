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

echo -e "______  $LINENO  ____  Reconfigure as an overlay /  squashfs system.  ___________________________\n"

################################################################################
LANG=C.UTF-8 chroot $WorkDir /qemu-${ProcArch}-static /bin/sh << 'EOInstall'

apt -y install squashfs-tools cloud-init systemd-container bindfs xorg fluxbox novnc tightvncserver xfonts-base oathtool qrencode

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

echo -e "______  $LINENO  ____  Build filesystem for 02-Cloud-init.  _____________________________________\n"

cp $FromBase/Files/cloud.cfg $WorkDir/etc/cloud/cloud.cfg

echo -e "______  $LINENO  ____  Build filesystem for 03-Container.  ______________________________________\n"

sed -i 's/--network-veth //' $WorkDir/usr/lib/systemd/system/systemd-nspawn\@.service

echo -e "______  $LINENO  ____  Build filesystem for 05-Desktop.  ________________________________________\n"

cp $FromBase/Files/KyaeolOS.jpg $WorkDir/usr/share/images/fluxbox/KyaeolOS.jpg
echo "session.screen0.workspaces: 1" >> $WorkDir/etc/X11/fluxbox/init
echo "session.screen0.toolbar.height: 32" >> $WorkDir/etc/X11/fluxbox/init
sed -i '/^background.pixmap: /c\background.pixmap:\t/usr/share/images/fluxbox/KyaeolOS.jpg' $WorkDir/usr/share/fluxbox/styles/Squared_for_Debian/theme.cfg

echo -e "______  $LINENO  ____  Build filesystem for 10-NoVNC.  __________________________________________\n"

find $WorkDir/usr/share/novnc -type d -exec touch {}/index.htm \;

mkdir $WorkDir/root/.vnc
echo "startfluxbox" > $WorkDir/root/.vnc/xstartup
chmod 755 $WorkDir/root/.vnc/xstartup

cp $FromBase/Files/novnc_authenticator $WorkDir/usr/local/sbin/
cp $FromBase/Files/ConnectVNC.sh $WorkDir/usr/local/sbin/

echo -e "______  $LINENO  ____  Clean up random files after installing $ImageTag.  _______________________\n"

rm $WorkDir/qemu-${ProcArch}-static
rm $WorkDir/etc/apt/apt.conf.d/90cache
rm -rf $WorkDir/var/cache/apt

echo -e "______  $LINENO  ____  Create Core xfs filesystem for $ImageTag.  _______________________________\n"

truncate $WorkDir.Core.xfs -s 10G
mkfs.xfs -L $ImageTag $WorkDir.Core.xfs
sync
mount -v $WorkDir.Core.xfs /mnt
mv $WorkDir/* /mnt/
umount -v /mnt
umount -v $WorkDir
mv $WorkDir.Core.xfs $WorkDir/Core.xfs
rm $WorkDir/Run.xfs

cat << EOInstall > $Workdir/boot/grub.cfg
set timeout=4
set default=Run

menuentry 'Run' --id 'Run' {
  linux (hd0,2)$ImageTag/boot/vmlinuz
  initrd (hd0,2)$ImageTag/boot/initrd (hd0,2)$ImageTag/boot/initroot
  options ImageTag=$ImageTag RootRW=Run boot=mountroot
}
EOInstall

echo -e "______  $LINENO  ____  Copy filesystem for 50-HostFirm.  ________________________________________\n"

truncate $WorkDir/Run.xfs -s 10G
mkfs.xfs -L Run $WorkDir/Run.xfs
sync
mount -v $WorkDir/Run.xfs /mnt
cp -r $FromBase/Files/50-HostFirm/* /mnt/
echo "$ImageTag" > /mnt/UpperDir/etc/hostname
cat << EOInstall > /mnt/UpperDir/etc/hosts
127.0.0.1	localhost.localdomain	localhost
127.0.0.1	$ImageTag.localdomain	$ImageTag
EOInstall
umount -v /mnt

echo -e "______  $LINENO  ____  Create a tar for easy upload.  ___________________________________________\n"

cd $ToBase
rm -f ${ImageTag}.tgz
tar -zcSf ${ImageTag}.tgz $ImageTag

echo "All is said and done.  Thusly, there is nothing more to say or do."
