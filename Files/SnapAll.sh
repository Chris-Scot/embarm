for MountPoint in $(mount|awk '/ on \/media\/.* type xfs /{print $3}'); do
   SnapTime=$(date +%F.%T)
   mkdir -p $MountPoint/.snapshot/$SnapTime
   echo "$(date +%F.%T)  Snapshot $MountPoint."
   cp -ax --reflink=always $MountPoint/* $MountPoint/.snapshot/$SnapTime/
   sync
done
echo "$(date +%F.%T)  Snapshot Complete."
