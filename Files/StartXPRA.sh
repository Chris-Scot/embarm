#!/bin/bash
if [ -d /Inception ]; then
   if [ ! -f $HOME/.xpra/self.pem ]; then
      openssl req -new -x509 -nodes -sha256 -days 3560 -subj "/CN=$HOSTNAME" -keyout $HOME/.xpra/self.pem -out $HOME/.xpra/self.pem
   fi
   xpra proxy --daemon=no --dbus-launch=no --bind-ssl=0.0.0.0:5900 --ssl-cert=$HOME/.xpra/self.pem --tcp-auth=multifile:filename=/usr/share/xpra/UserList
fi
if [ -f $HOME/.xpra/passwd ]; then
   if ps -ef|grep " /usr/bin/xpra start-desktop [:]0 "; then
      echo "It looks like there is already a XPRA desktop running for this host."
   else
      echo "Starting XPRA desktop on :0"
      xpra start-desktop :0 --dbus-launch=no --start=startfluxbox
   fi
else
   echo "XPRA is not ready.  Password not set."
fi

