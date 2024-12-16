if [ "$PublicIP" = "" ]; then
   echo "PublicIP is not defined."
else
   while true; do
      for Each in $(netstat -tnl|awk '/127\..*\..*\..*:/{print $4}'); do
         if ! ps|grep -q "[n]c -ll $PublicIP:${Each#*:} -e "; then
            if ! netstat -tnl|grep -qe "$PublicIP:${Each#*:}" -e "0.0.0.0:${Each#*:}"; then
               echo "Forwarding $PublicIP:${Each#*:} to $Each"
               nc -ll PublicIP:${Each#*:} -e /usr/local/bin/nc $Each &
            fi
         fi
      done
      sleep 1
   done
fi
