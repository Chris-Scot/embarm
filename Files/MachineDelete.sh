#!/bin/bash
Inception=/Inception
export MBase=/var/lib/machines

export MachineName=$1

if [ "$MachineName" = "" ]; then
   echo "ERROR:  Expecting something to delete."
   exit 1
fi

if [ "$(machinectl | grep "^$MachineName *container")" != "" ]; then
   echo "ERROR:  '$MachineName' is still running.  I would expect this to be stopped before deletion."
   exit 1
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

if [ -e "$Inception/$MachineName.xfs" ]; then
   echo "INFO:  Deleting root filesystem '$Inception/$MachineName.xfs'."
   SnapAll.sh
   rm $Inception/$MachineName.xfs
else
   echo "INFO:  Root filesystem '$Base/$MachineName.xfs' not found."
fi
