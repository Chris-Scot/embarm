#!/bin/bash
Inception=/Inception
export MBase=/var/lib/machines

export MachineName=$1

if [ "$MachineName" = "" ]; then
   echo "ERROR:  Expecting something to stop."
   exit 1
fi

if [ "$(machinectl | grep "^$MachineName *container")" = "" ]; then
   echo "WARNING:  '$MachineName' was not running."
else
   echo "INFO:  Stopping '$MachineName'."
   Running="Yes"
   machinectl stop $MachineName
   for Each in {1..10}; do
      if [ "$(machinectl | grep "^$MachineName *container")" = "" ]; then
         Running="No"
         break
      else
         sleep $Each
      fi
   done

   if [ "$Running" != "No" ]; then
      machinectl status $MachineName
      echo "ERROR:  Machine $MachineName does not appear to have stopped."
      exit 1
   fi
fi

if [ -x $Inception/$MachineName.sh ]; then
   $Inception/$MachineName.sh stop
fi

if [ -d "$MBase/$MachineName" ]; then
   echo "INFO:  Machine space '$MBase/$MachineName' found."
   if [ "$(stat -c %a "$MBase/$MachineName")" = "0" ]; then
      echo "INFO:  Root filesystem not not mounted."
   else
      echo "INFO:  Unmounting root filesystem."
      umount $MBase/$MachineName
   fi
   echo "INFO:  Removing machine space '$MBase/$MachineName'."
   rmdir "$MBase/$MachineName"
else
   echo "INFO:  Machine space '$MBase/$MachineName' not found."
fi

if [ -d "$MBase/.$MachineName.xfs" ]; then
   echo "INFO:  Overlay space '$MBase/.$MachineName.xfs' found."
   if [ "$(stat -c %a "$MBase/.$MachineName.xfs")" = "0" ]; then
      echo "INFO:  Overlay filesystem not not mounted."
   else
      echo "INFO:  Unmounting overlay filesystem."
      umount $MBase/.$MachineName.xfs
   fi
   echo "INFO:  Removing ovelay space '$MBase/.$MachineName.xfs'."
   rmdir "$MBase/.$MachineName.xfs"
else
   echo "INFO:  Overlay space '$MBase/.$MachineName.xfs' not found."
fi
echo "INFO:  Machine '$MachineName' Stopped."
