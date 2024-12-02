#!/bin/bash -e

echo -e "______  $LINENO  ____  Set default build variables.  ____________________________________________\n"

. $(dirname $(readlink -f $0))/?.*.env

echo -e "______  $LINENO  ____  Convert filesystems to SquashFS for installation $ImageTag.  _____________\n"

apt -y install squashfs-tools

mount -v $WorkDir/Core.xfs /mnt
mksquashfs /mnt "$WorkDir/Core.sq" -comp xz -b 1024K -Xbcj x86 -always-use-fragments -noappend
umount -v /mnt
rm $WorkDir/Core.xfs

echo -e "______  $LINENO  ____  Create a tar for easy upload.  ___________________________________________\n"

cd $ToBase
tar -cSf ${ImageTag}.tar $ImageTag

echo "All is said and done.  Thusly, there is nothing more to say or do."
