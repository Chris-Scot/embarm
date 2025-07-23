#!/bin/bash
if [ -f $HOME/.xpra/passwd ]; then
   if [ -S /usr/share/xpra/.xpra-0 ]; then
      echo "It looks like there is already a XPRA desktop running for this host."
   else
      echo "Starting XPRA desktop on :0"
      xpra start-desktop :0 --bind=/usr/share/xpra/.xpra-0 --socket-permissions=660 --dbus-launch=no --start=startfluxbox --no-pulseaudio
   fi
else
   echo "XPRA is not ready.  Password not set."
fi
