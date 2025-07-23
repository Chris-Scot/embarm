#!/bin/bash
if [ "$(which "${0##*/}")" = "$(readlink -f $0)" ]; then
   ThisScript="${0##*/}"
else
   ThisScript=$(readlink -f $0)
fi

if [ -d $Inception ]; then
   if [ "$1" = "" ]; then
      if [ ! -f /etc/xpra/ssl-cert.pem ]; then
         openssl req -new -x509 -nodes -sha256 -days 3560 -subj "/CN=$HOSTNAME" -keyout /etc/xpra/ssl-cert.pem -out /etc/xpra/ssl-cert.pem
         chmod 040 /etc/xpra/ssl-cert.pem
         chgrp xpra /etc/xpra/ssl-cert.pem
      fi
      if ! ps -fu nobody | grep -q ":.. stunnel4$"; then
         su nobody -g xpra -s "/bin/bash" -c stunnel4
      fi
      if ! firewall-cmd -q --query-service=https; then
         firewall-cmd --add-service=https
      fi
      if ! ps -fu nobody | grep -q 'xpra proxy --mdns=no'; then
         su nobody -g xpra -s "/bin/bash" -c "XDG_RUNTIME_DIR=/run; /usr/bin/xpra proxy --mdns=no --dbus-launch=no --dbus-control=no --socket-dir=/run/xpra --bind=none --bind-tcp=127.0.0.1:14500 --tcp-auth=multifile:filename=/usr/share/xpra/UserList"
      fi
      $ThisScript reload
   elif [ "$1" = "reload" ]; then
      for Each in $(ps -ef|awk '/[i]notifywait -mrPqe CLOSE_WRITE/{print $2}'); do
         kill $Each
      done
      chgrp xpra /var/lib/machines
      chmod 750 /var/lib/machines
      inotifywait -mrPqe "CLOSE_WRITE" -e "CREATE" --format "%e %w%f" --include "xpra/passwd||xpra/.xpra-0" /root /var/lib/machines | while read; do
         $ThisScript $REPLY
      done &
      if [ ! -f /usr/share/xpra/UserList ]; then
         touch -t 200001010000 /usr/share/xpra/UserList
      fi
      find /root /var/lib/machines -newer /usr/share/xpra/UserList -type f -path "*xpra/passwd" -exec $ThisScript "CLOSE_WRITE" {} \;
   elif [ "${1:0:11}" = "CLOSE_WRITE" -a "${2: -7}" = "/passwd" ]; then
      WhatHost="$HOSTNAME${2%/root/.xpra/passwd}"
      WhatHost="${WhatHost##*/}"
      UserLine="$WhatHost|$(head -1 $2)|$(stat -c '%u|%g' $2)|${2%/root/.xpra/passwd}/usr/share/xpra/.xpra-0"
      if ! grep -q "^$UserLine$" /usr/share/xpra/UserList; then
         Result="$(grep -v "|${UserLine##*|}$" /usr/share/xpra/UserList; echo "$UserLine")"
         echo "$Result" | sort > /usr/share/xpra/UserList
      fi
   elif [ "$1" = "CREATE" -a "${2: -8}" = "/.xpra-0" ]; then
      chgrp xpra $2
   fi
else
  echo "ERROR:  Not expected to run this in a container."
fi
