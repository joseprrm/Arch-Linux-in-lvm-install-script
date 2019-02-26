# Arch-Linux-lvm-install-script
Experimental script that installs Arch Linux on LVM. It will wipe out all the data in the selected drive, so use at your own risk. 

## Usage
Just run:
```
sh install.sh /dev/sdx
```

## Explanation
I just make the whole /run accessible to the chroot jail, because grub-mkconfig needs access to /run/lvm and /run/udev to run properly when Arch Linux is installed on LVM.
```
mkdir /mnt/hostrun
mount --bind /run /mnt/hostrun
arch-chroot /mnt
mount --bind /hostrun /run
```
