#!/bin/bash


if [ "$EUID" -ne 0 ]; then
	echo -e "Sorry, run as root \n"
	exit 1
fi


PARTITION=$(fdisk -l | grep "Disk" | awk 'NR==1 {printf "%s",$2}' | tr -d ':')
BOOT_PARTITION=$(df -h | grep "/boot" | awk 'NR==1 {printf "%s",$1}')

mount -oremount,ro /boot
install -m0600 /dev/null /tmp/boot.tar
tar -C /boot --acls --xattrs --one-file-system -cf /tmp/boot.tar .
umount /boot/efi
umount /boot
cryptsetup luksFormat --type luks1 $BOOT_PARTITION
UUID="$(blkid -o value -s UUID $BOOT_PARTITION)"
echo "boot_crypt UUID=$UUID none luks" | tee -a /etc/crypttab
cryptdisks_start boot_crypt
NUUID=$(grep /boot /etc/fstab | awk 'NR==2 {printf "%s",$1}' | cut -c 6-)
mkfs.ext2 -m0 -U $NUUID /dev/mapper/boot_crypt 
mount -v /boot/
tar -C /boot/ --acls --xattrs -xf /tmp/boot.tar 
mount -v /boot/efi/
echo "GRUB_ENABLE_CRYPTODISK=y" >>/etc/default/grub
update-grub
grub-install $PARTITION


#cryptsetup luksChangeKey --pbkdf-force-iterations 500000 $BOOT_PARTITION
#cryptsetup luksOpen --test-passphrase --verbose $BOOT_PARTITION
