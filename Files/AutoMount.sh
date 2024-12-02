IFS=$'\n'
for Each in $(blkid -s TYPE | grep -v '^/dev/loop' | grep -v ' TYPE="squashfs"$'); do
   ThisType=${Each##*TYPE=}
   ThisDev=${Each%%:*}
   Each=${ThisDev##*/}
   if [ "$Each" != "" ]; then
      if [ ! -d /media/$Each ]; then
         mkdir -m0 /media/$Each
      fi
      if [ "$(stat -c%a "/media/$Each")" = "0" ]; then
         mount -v $ThisDev /media/$Each
      fi
   fi
done
echo "All devices (if any) mounted."
