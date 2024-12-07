IFS=$'\n'
for Each in $(blkid -s TYPE -s LABEL | grep -v '^/dev/loop' | grep -v ' TYPE="squashfs" '); do
   ThisLabel=${Each##*LABEL=\"}
   ThisLabel=${ThisLabel%%\"*}
   ThisDev=${Each%%:*}
   MountPoint="$ThisLabel"
   if [ "$MountPoint" = "" ]; then
      MountPoint=${ThisDev##*/}
   else
      if [ ! -d "/media/$MountPoint" ]; then
         mkdir -m0 "/media/$MountPoint"
      fi
      if [ "$(stat -c%a "/media/$MountPoint")" = "0" ]; then
         mount -v $ThisDev "/media/$MountPoint"
         MountPoint=""
      elif  mount | grep "$ThisDev on /media/$MountPoint"; then
         MountPoint=""
      else
         MountPoint=${ThisDev##*/}
      fi
   fi

   if [ "$MountPoint" != "" ]; then
      if [ ! -d "/media/$MountPoint" ]; then
         mkdir -m0 "/media/$MountPoint"
      fi
      if [ "$(stat -c%a "/media/$MountPoint")" = "0" ]; then
         mount -v $ThisDev "/media/$MountPoint"
         MountPoint=""
      elif  mount | grep "$ThisDev on /media/$MountPoint"; then
         MountPoint=""
      else
         echo "Don't know how to mount $Each"
      fi
   fi
done
echo "All devices (if any) mounted."
