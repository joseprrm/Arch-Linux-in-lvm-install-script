#!/bin/bash
set -e
set -u

cat > /etc/pacman.d/mirrorlist <<"EOF"
Server = http://ftp.rediris.es/mirror/archlinux/$repo/os/$arch
Server = http://osl.ugr.es/archlinux/$repo/os/$arch
Server = http://archlinux.de-labrusse.fr/$repo/os/$arch
Server = http://archlinux.vi-di.fr/$repo/os/$arch
Server = https://archlinux.vi-di.fr/$repo/os/$arch
EOF

target_device=$1

timedatectl set-ntp true

# Do not put blank lines until EOF (unless you know what you are doing), because they will be interpreted as a <CR> inside fdisk
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${target_device}
  o # create a DOS partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +200M # 100 MB boot parttion
  n # new partition
  p # primary partition
  2 # partition number 2
    # default - start next to the partiton1
    # default - until the end of the disk
  t # change partition type
  2 # select partition 2
  8e # type Linux LVM
  w # write the partition table
  q # and we're done
EOF

boot_partition=${target_device}1
lvm_partition=${target_device}2

pvcreate ${lvm_partition}
pv_path=${lvm_partition}

vg_name=vg1

vgcreate ${vg_name} ${pv_path}
vg_path=/dev/${vg_name}

lv_swap_name=lv_swap
lv_root_name=lv_root

lvcreate -L 1G ${vg_name} -n ${lv_swap_name}
lvcreate -l 100%FREE ${vg_name} -n ${lv_root_name}

lv_swap_path=${vg_path}/lv_swap
lv_root_path=${vg_path}/lv_root

mkswap ${lv_swap_path}
swapon ${lv_swap_path}
mkfs.ext4 ${lv_root_path}
mkfs.ext4 ${boot_partition}

mount ${lv_root_path} /mnt
mkdir /mnt/boot
mount ${boot_partition} /mnt/boot

pacstrap /mnt base grub 

mkdir /mnt/hostrun
mount --bind /run /mnt/hostrun

arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
echo "archvm " > /etc/hostname 

mount --bind /hostrun /run

sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

grub-install --target=i386-pc ${target_device}
sed -i 's/GRUB_PRELOAD_MODULES="part_gpt part_msdos"/GRUB_PRELOAD_MODULES="part_gpt part_msdos lvm2"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

umount /run
exit
EOF

umount /mnt/hostrun
rmdir /mnt/hostrun
genfstab -U /mnt >> /mnt/etc/fstab
umount /mnt/boot
umount /mnt
