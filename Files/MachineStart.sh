#!/bin/bash
Inception=/Inception
export MBase=/var/lib/machines
if [ -e  $Inception/Core.sq ]; then
   CoreFile=Core.sq
elif [ -e  $Inception/Core.xfs ]; then
   CoreFile=Core.xfs
else
   echo "Can't find a Core file."
   exit 1
fi

if [ ! -d $Inception/.$CoreFile ]; then
   mkdir -m0 $Inception/.$CoreFile
fi
if [ "$(stat -c %a "$Inception/.$CoreFile")" = "0" ]; then
   mount -v $Inception/$CoreFile $Inception/.$CoreFile
fi

LowerDirs=":$Inception/.$CoreFile"

export MachineName=$1
export ServerName=${1,,}

if [ "$MachineName" = "" ]; then
   echo "ERROR:  Expecting something to start."
   exit 1
fi

if [ "$(machinectl | grep "^$MachineName *container")" != "" ]; then
   echo "INFO:  Machine '$MachineName' is already running."
   exit
fi

if [ -e "$Inception/$MachineName.xfs" ]; then
   if [ "$2" != "" ]; then
      echo "ERROR:  Machine '$MachineName' exits.  Not expecting a second parameter ($2)."
      exit 1
   fi
else
   if [ "$2" != "create" ]; then
      echo "ERROR:  Use '$0 $MachineName create ' to create a new machine."
      exit 1
   fi
fi

if [ -d "$MBase/$MachineName" ]; then
   echo "INFO:  Machine space '$MBase/$MachineName' found."
else
   echo "INFO:  Creating machine space '$MBase/$MachineName'."
   mkdir -m0 "$MBase/$MachineName"
fi

if [ "$(stat -c %a "$MBase")" != "750" ]; then
   chmod 750 "$MBase"
fi
if [ "$(stat -c %G "$MBase")" != "xpra" ]; then
   chgrp xpra "$MBase"
fi

if [ "$(stat -c %a "$MBase/$MachineName")" = "0" ]; then
   echo "INFO:  Mount filesystem."
   if [  -e "$Inception/$MachineName.xfs" ]; then
      echo "INFO:  Root filesystem '$Inception/$MachineName.xfs' found."
      mount -v $Inception/$MachineName.xfs $MBase/$MachineName
      if [ -d "$MBase/$MachineName/UpperDir" -a -d "$MBase/$MachineName/WorkDir" ]; then
         if [ ! -d $MBase/.$MachineName.xfs ]; then
            mkdir -m0 $MBase/.$MachineName.xfs
         fi
         umount -v $MBase/$MachineName
         mount -v $Inception/$MachineName.xfs $MBase/.$MachineName.xfs
         mount -vt overlay overlay -o xino=on,metacopy=on,lowerdir=${LowerDirs:1},upperdir=$MBase/.$MachineName.xfs/UpperDir,workdir=$MBase/.$MachineName.xfs/WorkDir $MBase/$MachineName
      else
         echo "INFO:  Root filesystem looks like a clone.  Mounted direct."
      fi
   else
      if [ "$2" = "create" ]; then
         echo "INFO:  Creating root filesystem '$Inception/$MachineName.xfs'."
         truncate $Inception/$MachineName.xfs --size=10G
         mkfs.xfs -L $MachineName $Inception/$MachineName.xfs
         if [ ! -d $MBase/.$MachineName.xfs ]; then
            mkdir -m0 $MBase/.$MachineName.xfs
         fi
         if [ "$(stat -c %a "$MBase/.$MachineName.xfs")" = "0" ]; then
            mount -v $Inception/$MachineName.xfs $MBase/.$MachineName.xfs
         else
            echo "ERROR:  It looks like the overlay file system ($MBase/.$MachineName.xfs) is being used."
            echo "        The filesystem has been left partially created on '$Inception/$MachineName.xfs'."
            exit 1
         fi
         mkdir $MBase/.$MachineName.xfs/UpperDir $MBase/.$MachineName.xfs/WorkDir
         mount -vt overlay overlay -o xino=on,metacopy=on,lowerdir=${LowerDirs:1},upperdir=$MBase/.$MachineName.xfs/UpperDir,workdir=$MBase/.$MachineName.xfs/WorkDir $MBase/$MachineName
         echo "${ServerName}" > $MBase/$MachineName/etc/hostname
         echo -e "127.0.0.1\tlocalhost.localdomain\tlocalhost" > $MBase/$MachineName/etc/hosts

#         rm -rf $MBase/$MachineName/etc/acpi/events
#         cp /etc/resolv.conf $MBase/$MachineName/etc/resolv.conf
#         echo "INFO:  Clearing machine-id."
#         :> $MBase/$MachineName/etc/machine-id
#         ln -fs /etc/machine-id $MBase/$MachineName/var/lib/dbus/machine-id
#         sed -i '/^PATH=/c\PATH=/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin' $MBase/$MachineName/etc/crontab
#         sed -i '/^ *PATH=/c\  PATH=/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin' $MBase/$MachineName/etc/profile
#                sed -i '/^guest:/d' $MBase/$MachineName/etc/passwd
#                sed -i '/^guest:/d' $MBase/$MachineName/etc/group
#                sed -i 's/guest//' $MBase/$MachineName/etc/group
#                rm -rf $MBase/$MachineName/home/guest
      else
         echo "ERROR:  '$2' should be 'create'."
         exit 1
      fi
   fi
else
   echo "INFO: Filesystem already mounted."
fi

echo "INFO:  Starting '$MachineName'."
StartProxy.sh reload
Running="No"
machinectl start $MachineName
for Each in {1..10}; do
   if [ "$(systemctl show "systemd-nspawn@$MachineName" -P StatusText)" = "Container running: Ready." ]; then
      Running="Yes"
      break
   else
      sleep $Each
   fi
done

if [ "$Running" = "Yes" ]; then
   if [ -f $MBase/$MachineName/root/.xpra/passwd ]; then
      if ! grep -q "^$MachineName|$(head -1 $MBase/$MachineName/root/.xpra/passwd)|" /usr/share/xpra/UserList; then
         touch $MBase/$MachineName/root/.xpra/passwd
      fi
   fi

   if [ -x $Inception/$MachineName.sh ]; then
      $Inception/$MachineName.sh start
   fi
else
   machinectl status $MachineName
   echo "ERROR:  Machine $MachineName does not appear to have started."
   exit 1
fi
echo "INFO:  Machine '$MachineName' Started."
