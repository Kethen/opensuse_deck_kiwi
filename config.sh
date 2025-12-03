#!/bin/bash

# kiwi functions
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

set -xe

is_nvidia=false
if [ "$kiwi_profiles" == "with-KDE-nvidia" ] || [ "$kiwi_profiles" == "with-GNOME-nvidia" ]
then
	is_nvidia=true
fi

BUILD_PACKAGES=false

TEMP_PACKAGES="git rpm-build cargo cmake gcc-c++ fontconfig-devel rpm-build"

if $BUILD_PACKAGES
then
	zypper -n --gpg-auto-import-keys install $TEMP_PACKAGES
fi

# build and install some packages
if $BUILD_PACKAGES
then
	cd /
	git clone --depth 1 https://github.com/Kethen/opensuse_deck.git
	cd opensuse_deck
	cp rpmmacros ~/.rpmmacros
	rpmbuild -bb deck-adaptation-for-opensuse.spec
	zypper -n --gpg-auto-import-keys install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-adaptation-for-opensuse-0.1-0.x86_64.rpm
	cd /
	rm -r opensuse_deck
else
	zypper -n --gpg-auto-import-keys install --allow-unsigned-rpm https://github.com/Kethen/opensuse_deck/releases/download/2025-12-01/deck-adaptation-for-opensuse-0.1-0.x86_64.rpm
fi

if $BUILD_PACKAGES
then
	git clone --depth 1 https://github.com/Kethen/Simple-Steam-Deck-TDP-Slider.git
	cd Simple-Steam-Deck-TDP-Slider
	rpmbuild -bb deck-tdp-slider.spec
	zypper -n --gpg-auto-import-keys install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-tdp-slider-0.1-0.x86_64.rpm
	cd /
	rm -rf Simple-Steam-Deck-TDP-Slider
	rm -rf /root/.cargo
else
	zypper -n --gpg-auto-import-keys install --allow-unsigned-rpm https://github.com/Kethen/Simple-Steam-Deck-TDP-Slider/releases/download/2023-09-13/deck-tdp-slider-0.1-0.x86_64.rpm
fi

if $BUILD_PACKAGES
then
	zypper -n remove --clean-deps $TEMP_PACKAGES
	zypper -n clean -a
fi

# install input methods and some fonts for fallback
set +e
zypper -n --gpg-auto-import-keys install 'google-noto-*' 'ibus-*'
status_code=$?
if [ "$status_code" != "107" ] && [ "$status_code" != "0" ]
then
	echo zypper -n --gpg-auto-import-keys install 'google-noto-*' 'noto-*-fonts' 'ibus-*' exited with $status_code
	exit 1
fi
set -e

# manpages
zypper -n --gpg-auto-import-keys install man man-pages

# copy screen orientation from opensuse_deck
tar -C /etc/skel -cO .local/share/kscreen | tar -C /home/deck -xv
chown -R deck:deck /home/deck/.local

# install nvidia drivers
if $is_nvidia
then
	zypper -n clean -a
	zypper -n --gpg-auto-import-keys install --auto-agree-with-licenses nvidia-video-G06 nvidia-video-G06-32bit nvidia-gl-G06 nvidia-gl-G06-32bit nvidia-compute-G06 nvidia-compute-G06-32bit nvidia-compute-utils-G06 2>/dev/null 1>/dev/null

	# mark all nvidia devices witih uaccess
	idx=0
	while [ $idx -lt 128 ]
	do
		echo "L /run/udev/static_node-tags/uaccess/nvidia${idx} - - - - /dev/nvidia${idx}" >> /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06-ext.conf
		idx=$((idx + 1))
	done
fi

# disable root
passwd -l root

# configure snapper as https://build.opensuse.org/package/show/openSUSE:Factory/openSUSE-MicroOS would
cp /usr/share/snapper/config-templates/default /etc/snapper/configs/root

sed -i'' 's/^TIMELINE_CREATE=.*$/TIMELINE_CREATE="no"/g' /etc/snapper/configs/root
sed -i'' 's/^NUMBER_LIMIT=.*$/NUMBER_LIMIT="2-10"/g' /etc/snapper/configs/root
sed -i'' 's/^NUMBER_LIMIT_IMPORTANT=.*$/NUMBER_LIMIT_IMPORTANT="4-10"/g' /etc/snapper/configs/root

baseUpdateSysConfig /etc/sysconfig/snapper SNAPPER_CONFIGS root

# toggle some services
systemctl enable NetworkManager
systemctl disable sshd
systemctl disable firewalld
systemctl enable earlyoom
systemctl enable zramswap

# disable autoupdate
systemctl mask transactional-update.service

# force ibus
#echo 'export GTK_IM_MODULE=ibus
#export XMODIFIERS=@im=ibus
#export QT_IM_MODULE=ibus' >> /etc/skel/.profile

#cp /etc/skel/.profile /home/deck/.profile
#chown deck:deck /home/deck/.profile

# cups access from group wheel
sed -i'' 's/^SystemGroup root/SystemGroup wheel/' /etc/cups/cups-files.conf

if [ "$kiwi_profiles" == "with-KDE-nvidia" ] || [ "$kiwi_profiles" == "with-KDE" ]
then
	# uninstall vlc and falkon in the kde build
	zypper -n remove vlc falkon
fi

# lock a few recommended packages that gets pulled in during updates
zypper -n addlock MozillaFirefox chromium libreoffice vlc falkon

if false
then
	# install kernel-default
	zypper -n --gpg-auto-import-keys install kernel-default
fi

if false
then
	# lock kernel-default away
	zypper -n addlock kernel-default
	rm -f /boot/vmlinuz*
	rm -f /boot/initrd*
fi

if false
then
	# install kernel-longterm
	zypper -n --gpg-auto-import-keys install kernel-longterm
fi

if false
then
	# install steamos kernels
	mkdir steamos_kernel
	cd steamos_kernel

	#wget "https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-3.6/os/x86_64/linux-neptune-61-6.1.52.valve9-1-x86_64.pkg.tar.zst" -O - | zstd -d -T0 | tar -xv
	wget "https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-3.6/os/x86_64/linux-neptune-65-6.5.0.valve21-1-x86_64.pkg.tar.zst" -O - | zstd -d -T0 | tar -xv
	#VERSION=6.1.52-valve9-1-neptune-61
	VERSION=6.5.0-valve21-1-neptune-65-g33487bf05ed3
	mv usr/lib/modules/$VERSION /usr/lib/modules/$VERSION
	cp /usr/lib/modules/$VERSION/vmlinuz /boot/vmlinuz-$VERSION
	kernel-install add $VERSION /usr/lib/modules/$VERSION/vmlinuz

	cd /
	rm -rf steamos_kernel
fi

# default to nano
echo 'export EDITOR=nano' >> /etc/skel/.profile

cp /etc/skel/.profile /home/deck/.profile
chown deck:deck /home/deck/.profile

# install codecs
zypper -n addrepo -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/' packman
zypper --gpg-auto-import-keys -n install --allow-vendor-change --from packman ffmpeg gstreamer-plugins-{good,bad,ugly,libav} libavcodec vlc-codecs Mesa-libva

zypper -n clean -a
