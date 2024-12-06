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

LowerDirs=":$MBase/.$CoreFile"

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

if [ ! -d $MBase/.$CoreFile ]; then
   mkdir -m0 $MBase/.$CoreFile
fi
if [ "$(stat -c %a "$MBase/.$CoreFile")" = "0" ]; then
   mount -v $Inception/$CoreFile $MBase/.$CoreFile
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

HLoopIP=$(awk -F '.' '/\t'$ServerName'\t/||/\t'$ServerName'$/{print $2}' /etc/hosts)
if [ "$HLoopIP" = "" ]; then
   GLoopIP=$(awk -F '.' '/\t'$ServerName'\t/||/\t'$ServerName'$/{print $2}' $MBase/$MachineName/etc/hosts)
   if [ "$GLoopIP" = "" ]; then
      echo "INFO:  Creating new loopback IP for Guest & Host."
      HLoopIP=$(awk -F '.' '/^127\./{print $2 +1}' /etc/hosts | sort | tail -1)
      echo -e "127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" >> /etc/hosts
      echo -e "127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" >> $MBase/$MachineName/etc/hosts
   else
      if grep "^127.$GLoopIP.0.1\t" /etc/hosts; then
         echo "WARNING:  Guest loopback IP exists for another guest."
         echo "INFO:  Creating new loopback IP for Guest & Host."
         HLoopIP=$(awk -F '.' '/^127\./{print $2 +1}' /etc/hosts | sort | tail -1)
         echo -e "127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" >> /etc/hosts
         sed -i "/127.$GLoopIP.0.1\t/c\127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" $MBase/$MachineName/etc/hosts
      else
         echo "INFO:  Updating Host loopback IP from Guest."
         HLoopIP=$GLoopIP
         echo -e "127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" >> /etc/hosts
      fi
   fi
else
   GLoopIP=$(awk -F '.' '/\t'$ServerName'$/{print $2}' $MBase/$MachineName/etc/hosts)
   if [ "$GLoopIP" = "" ]; then
      echo "INFO:  Creating new loopback IP for Guest from Host."
      echo -e "127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" >> $MBase/$MachineName/etc/hosts
   else
      if [ "$HLoopIP" = "$GLoopIP" ]; then
         echo "INFO:  Guest & Host loopback IP match."
      else
         echo "WARNING:  Updating Guest loopback IP from Host."
         sed -i "/127.$GLoopIP.0.1\t/c\127.$HLoopIP.0.1\t${ServerName}.localdomain\t${ServerName}" $MBase/$MachineName/etc/hosts
      fi
   fi
fi

echo "INFO:  Starting '$MachineName'."
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
   if [ -x $Inception/$MachineName.sh ]; then
      $Inception/$MachineName.sh start
   fi
else
   machinectl status $MachineName
   echo "ERROR:  Machine $MachineName does not appear to have started."
   exit 1
fi
echo "INFO:  Machine '$MachineName' Started."
