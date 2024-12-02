#!/bin/bash -e

echo -e "______  $LINENO  ____  Set default build variables.  ____________________________________________\n"

. $(dirname $(readlink -f $0))/?.*.env

echo -e "______  $LINENO  ____  Create Run xfs filesystem for $ImageTag.  _______________________________\n"

mv $WorkDir $WorkDir.tmp
mkdir $WorkDir
mv $WorkDir.tmp/boot $WorkDir/
mkdir -m0 $WorkDir.tmp/boot
truncate $WorkDir/Run.xfs -s 10G
mkfs.xfs -L $ImageTag $WorkDir/Run.xfs
sync
mount -v $WorkDir/Run.xfs /mnt
mv $WorkDir.tmp/* /mnt/
rmdir $WorkDir.tmp
umount -v /mnt

echo -e "______  $LINENO  ____  Create a tar for easy upload.  ___________________________________________\n"

cd $ToBase
rm -f ${ImageTag}.tgz
tar -zcSf ${ImageTag}.tgz $ImageTag

echo "All is said and done.  Thusly, there is nothing more to say or do."
