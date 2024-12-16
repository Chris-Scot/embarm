SnapTime=$(date +%F.%T)
for MountPoint in $(mount|awk '/ on \/media\/.* type xfs /{print $3}'); do
   if [ -d $MountPoint/.snapshot/$SnapTime ]; then
      echo "Snapshot '$MountPoint/.snapshot/$SnapTime' already exists.  Is this filesystem mounted twice?"
   else
      mkdir -p $MountPoint/.snapshot/$SnapTime
      echo "$(date +%F.%T)  Snapshot $MountPoint."
      cp -ax --reflink=always $MountPoint/* $MountPoint/.snapshot/$SnapTime/
      sync
   fi
done
echo "$(date +%F.%T)  Snapshot Complete."
