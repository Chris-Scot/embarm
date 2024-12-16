#!/bin/bash
if [ -f $HOME/.vnc/passwd ]; then
   function ps {
      if [ "$1" = "-p" ]; then
         /usr/local/bin/ps -o pid | grep " $2$"
      else
         /usr/local/bin/ps $@
       fi; }
   export -f ps
   LoopIP=$(awk '/\t'$HOSTNAME'\t/||/\t'$HOSTNAME'$/{print $1}' /etc/hosts)
   if [ "$LoopIP" = "" ]; then
      echo "Can't determine loopback address for this host."
   else
      if ps -ef|grep " \-desktop $HOSTNAME \-interface"; then
         echo "It looks like there is already a VNC desktop running for this host."
      else
         if [ "$Display" = "" ]; then
            echo "Can't determine a display number for VNC."
         else
            if vncserver $Display -geometry 1600x900 -dpi 150 -desktop $HOSTNAME -interface $LoopIP -nolisten tcp; then
               Display=${Display:1}
               if [ ! -e $HOME/.vnc/self.pem ]; then
                  openssl req -new -x509 -nodes -sha256 -days 3560 -subj "/CN=$HOSTNAME" -keyout $HOME/.vnc/self.pem -out $HOME/.vnc/self.pem
               fi
               echo "Starting NoVNC on $LoopIP:$((6080 + $Display)) connecting to VNC on $LoopIP:$((5900 + $Display))"
               /usr/share/novnc/utils/novnc_proxy --ssl-only --cert $HOME/.vnc/self.pem --listen $LoopIP:$((6080 + $Display)) --vnc $LoopIP:$((5900 + $Display)) &
               if [ "$PublicIP" = "" ]; then
                  echo "Can't determine network address for this host."
               else
                  /usr/local/sbin/ConnectVNC.sh $PublicIP:$((6080 + $Display)) $LoopIP:$((6080 + $Display)) &
               fi
            fi
         fi
      fi
   fi
else
   echo "VNC is not ready.  Password not set."
fi
