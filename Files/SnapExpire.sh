for MountPoint in $(mount|awk '/ on \/media\/.* type xfs /{print $3}'); do
   SnapZone="$MountPoint/.snapshot"
   if [ -d "$SnapZone" ]; then
      echo "$(date +%F.%T)  Starting purge of expired snapshots in $SnapZone."
      for Each in $SnapZone/2*; do
         ThisDate=${Each##*/}
         if [ "${ThisDate:8:2}" = "01" -a $(date +%s -d "1 year ago") -lt $(date +%s -d "${ThisDate%%.*}") ]; then
            echo "$(date +%F.%T)  Keep Monthly $ThisDate."
         elif [ $(date +%s -d "1 month ago") -lt $(date +%s -d "${ThisDate%%.*}") ]; then
            echo "$(date +%F.%T)  Keep 1 month $ThisDate."
         else
            echo "$(date +%F.%T)  Remove $Each."
            rm -rf "$Each"
         fi
      done
   else
      echo "$(date +%F.%T)  Can't find .snapshot directory for $MountPoint."
   fi
done
echo "$(date +%F.%T)  Purge of expired snapshots complete."
