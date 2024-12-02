PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

LoopIP=$(awk '/^127\..*\t'$HOSTNAME'\t/||/^127\..*\t'$HOSTNAME'$/{print $1}' /etc/hosts)
if [ "$LoopIP" = "" ]; then
   echo "ERROR:  Can't determine loopback address for this host." >&2
else
   export LoopIP
   Display=${LoopIP#*.}
   Display=${Display%%.*}
   if [ "$Display" != "" -a $Display -ge 0 -a $Display -le 255 ]; then
      export Display=":$Display"
   else
      echo "ERROR:  Display '$Display' can not be set from '$LoopIP'."
   fi
fi

PublicIP=$(ip link|awk '/<BROADCAST,/{print $2}')
PublicIP=$(ip addr show dev $PublicIP|awk '/^ *inet /{print $2}')
PublicIP=${PublicIP%%/*}
if [ "$PublicIP" = "" ]; then
   echo "ERROR:  Can't determine network address for this host."
else
   export PublicIP
fi
