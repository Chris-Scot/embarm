PublicIP=10.0.2.15
while true; do
   for Each in $(netstat -tnl|awk '/127\..*\..*\..*:/{print $4}'); do
      if ! ps|grep -q "[n]c -ll 10.0.2.15:${Each#*:} -e /usr/local/bin/nc $Each"; then
         echo "Forwarding 10.0.2.15:${Each#*:} to $Each"
         nc -ll 10.0.2.15:${Each#*:} -e /usr/local/bin/nc $Each &
      fi
   done
   sleep 1
done
