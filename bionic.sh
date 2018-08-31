#!/bin/bash
RELEASE=bionic
TARGET_DIR=$PWD/ubuntu
CACHE_DIR=$PWD/cache
MIRROR=http://mirror.yandex.ru/ubuntu
IMAGE=$RELEASE.qcow2
PKGS=linux-virtual,grub-pc,openssh-server,locales,nano,iputils-ping,iputils-arping,isc-dhcp-client,ifupdown
IMG_USER=user
IMG_PASSWD=password

if [[ ! -d $CACHE_DIR ]]; then mkdir -p $CACHE_DIR; fi
if [[ -d $TARGET_DIR ]]; then rm -rf $TARGET_DIR; fi
mkdir $TARGET_DIR

debootstrap --include $PKGS --cache-dir $CACHE_DIR --arch amd64 $RELEASE $TARGET_DIR $MIRROR

export PATH=/bin:/usr/sbin:$PATH

# clear downloaded packages
LANG=C chroot $TARGET_DIR apt-get clean

# copy configs
cp ./files/resolv.conf $TARGET_DIR/etc/
cp ./files/grub $TARGET_DIR/etc/default/
cp ./files/sshd_config $TARGET_DIR/etc/ssh/
cp ./files/interfaces $TARGET_DIR/etc/network/

# create users
LANG=C chroot $TARGET_DIR useradd $IMG_USER -ms /bin/bash
LANG=C chroot $TARGET_DIR gpasswd -a $IMG_USER sudo
LANG=C chroot $TARGET_DIR sh -c "echo $IMG_USER:$IMG_PASSWD | chpasswd"

# copy ssh-keys
mkdir $TARGET_DIR/home/$IMG_USER/.ssh/
cp ./files/authorized_keys $TARGET_DIR/home/$IMG_USER/.ssh/
chmod 0700 $TARGET_DIR/home/$IMG_USER/.ssh
chmod 0600 $TARGET_DIR/home/$IMG_USER/.ssh/authorized_keys

virt-make-fs --size=2G --format=qcow2 --type=ext4 --partition -- $TARGET_DIR $IMAGE

guestfish -a $IMAGE << EOF
run
mount /dev/sda1 /
sh "echo -n UUID=`blkid /dev/sda1 -s UUID -o value` > /etc/fstab"
sh "echo \" / ext4 rw,defaults 0 0\" >> /etc/fstab"
sh "/usr/sbin/grub-install --recheck --no-floppy /dev/sda"
sh "/usr/sbin/update-grub2"
sh "chown -R $IMG_USER:$IMG_USER /home/$IMG_USER/.ssh"
EOF

qemu-img convert -O qcow2 $IMAGE image-devops-`date +%s`.qcow2
