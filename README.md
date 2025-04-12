# embarm
Small debian install for oracle cloud built using qemu.

Still working on the finer points but you can get a working system with this.

Embarm.  Emulated Machine Build for ARM processors.  I suppose I should have rummaged harder to see if there were any cloud offerings that had access to the Debian repositories.
I was lazy and I used what I had to hand which was a server running slax in qemu on x86_64.
You can start this build using any Debian based system on any architecture.

This procedure has been put together to get a debian installation onto Oracle's very generous "Always Free" cloud accounts.
Understandably, Oracle provide a limited amount of disk space with this offering.  The phases of this install will incrementally reduce the amount of storage used by the core OS.  Thusly, there will be more available for your data.
If you can get one, the ARM servers have a very generous RAM & CPU allowance.

The format of this installation was inspired by slax, written by Tomáš Matějíček.  Slax needs very little work to get it to go on Oracle Cloud.  If slax was available for ARM, that would be the way to go.

Concepts.
1.  Leave the uefi alone and add a new OS.
2.  Build the system using qemu so a system running x86 can produce an install for ARM (or x86).
3.  Build in stages.  You can stop at a level where you have what you want.
4.  Put this OS all in one directory so it is easy to move about.
5.  Run from a disk image on a filesystem.  This can then be copied / backed up using reflink.
6.  Compress the image using squashfs saving a lot of space.  Add a RO layer in the middle for firm changes.  Add a RW layer on top.
7.  Use systemd-container to separate work.  This will re-use disk images.

The build process will move a repository cache from time to time.
Moving the cache out, at the end of the build will reduce the build size.
Moving the cache back into the build will expedite the build if it is re-run.
---
Build Process.  Raw install.
Choose a suitable place for the build scripts.  
mkdir EInstall  
cd EInstall  

Get the environment file and initial build file.  You can, of course, use git to acquire all the files.
...
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/0.SetEnv.env
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/1.RawInstall.sh
chmod 744 ?.*.sh
...

Make a directory to contain the build.  This does not need to be a mountpoint.  The build will be contained in a single directory for ease of transport.  A tar file is produced at the end of each phase of the build.
...
mkdir /media/sda2
...

Edit 0.SetEnv.env for any specific requirements.  Then run the build.
...
./1.RawInstall.sh
...

Once the build is complete, you can scp the tar archive to a cloud server, extract and re-boot into the debian system.
...
scp /media/sda2/<BuildName>.tgz opc@YourServerIP:~/
...

Log in as root to the Oracle Cloud server (usually as opc then sudo).
...
sudo su -
tar -zxf /home/opc/<BuildName>.tgz -C /boot
...

Switch out the defaut Oracle boot and replace with the Debian boot.
...
mv /boot/grub2/grub.cfg /boot/grub2/grub.cfg.std
ln /boot/<BuildName>/boot/grub.cfg /boot/grub2/grub.cfg
...

copy ssh keys or chroot to this directory structure to enable some form of login.
...
cp -rp /home/opc/.ssh /boot/<BuildName>/home/opc/

cp /etc/resolv.conf /boot/<BuildName>/etc/

reboot
...

#######################################################

Build Process.  Full install.
Choose a suitable place for the build scripts.
...
mkdir EInstall
cd EInstall
...

Get the environment file and initial build file.  You can, of course, use git to acquire all the files.
...
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/0.SetEnv.env
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/1.RawInstall.sh
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/2.MakeXFS.sh
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/3.MakeOverlay.sh
wget https://github.com/Chris-Scot/embarm/raw/refs/heads/main/4.MakeSquash.sh
chmod 744 ?.*.sh
...

Make a directory to contain the build.  This does not need to be a mountpoint.  The build will be contained in a single directory for ease of transport.  A tar file is produced at the end of each phase of the build.
...
mkdir /media/sda2
...

Edit 0.SetEnv.env for any specific requirements.  Then run the build.
...
./1.RawInstall.sh
./2.MakeXFS.sh
./3.MakeOverlay.sh
./4.MakeSquash.sh
...

Once the build is complete, you can scp the tar archive to a cloud server, extract and re-boot into the debian system.
...
scp /media/sda2/<BuildName>.tar opc@YourServerIP:~/
...

Log in as root to the Oracle Cloud server (usually as opc then sudo).
...
sudo su -
tar -xf /home/opc/<BuildName>.tar -C /boot
...

Switch out the defaut Oracle boot and replace with the Debian boot.
...
mv /boot/grub2/grub.cfg /boot/grub2/grub.cfg.std
ln /boot/<BuildName>/boot/grub.cfg /boot/grub2/grub.cfg
...

copy ssh keys or chroot to this directory structure to enable some form of login.
...
mount /boot/<BuildName>/Run.xfs /mnt
cp -rp /home/opc/.ssh /mnt/home/opc/
cp /etc/resolv.conf /mnt/etc/

reboot
...

#######################################################

One the system is running, you can delete the original OS installation and expand the boot filesystem.

Finally, for some reason I thought I needed to install:
...
apt install ca-certificates
...
