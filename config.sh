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

TEMP_PACKAGES="git rpm-build cargo cmake gcc-c++ fontconfig-devel rpm-build"

zypper -n --gpg-auto-import-keys install $TEMP_PACKAGES

# build and install some packages
cd /
git clone --depth 1 https://github.com/Kethen/opensuse_deck.git
cd opensuse_deck
cp rpmmacros ~/.rpmmacros
rpmbuild -bb deck-adaptation-for-opensuse.spec
zypper -n --gpg-auto-import-keys install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-adaptation-for-opensuse-0.1-0.x86_64.rpm
cd /
rm -r opensuse_deck

git clone --depth 1 https://github.com/Kethen/Simple-Steam-Deck-TDP-Slider.git
cd Simple-Steam-Deck-TDP-Slider
rpmbuild -bb deck-tdp-slider.spec
zypper -n --gpg-auto-import-keys install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-tdp-slider-0.1-0.x86_64.rpm
cd /
rm -rf Simple-Steam-Deck-TDP-Slider
rm -rf /root/.cargo

zypper -n remove --clean-deps $TEMP_PACKAGES

# install input methods and some fonts for fallback
set +e
zypper -n --gpg-auto-import-keys install 'google-noto-*' 'noto-*-fonts' 'ibus-*'
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
tar -C / -cO etc/skel/.local/share/kscreen | tar -C /home/deck -xv
chown -R deck:deck /home/deck/.local

# install nvidia drivers
if $is_nvidia
then
	zypper -n clean -a
	zypper -n --gpg-auto-import-keys install --auto-agree-with-licenses nvidia-video-G06 nvidia-video-G06-32bit nvidia-gl-G06 nvidia-gl-G06-32bit nvidia-compute-G06 nvidia-compute-G06-32bit nvidia-compute-utils-G06

	# mark all nvidia devices witih uaccess
	idx=0
	while [ $idx -lt 128 ]
	do
		echo "L /run/udev/static_node-tags/uaccess/nvidia${idx} - - - - /dev/nvidia${idx}" >> /usr/lib/tmpfiles.d/nvidia-logind-acl-trick-G06.conf
		idx=$((idx + 1))
	done
fi

zypper -n clean -a

# disable root
passwd -l root
# steamos update dummys sudoer file is 99
echo '%wheel  ALL=(ALL)       ALL' > /etc/sudoers.d/98_deck_pw_sudo
sed -iE '/^ALL   ALL=(ALL) ALL/d' /etc/sudoers
sed -iE '/^Defaults targetpw/d' /etc/sudoers

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

# disable autoupdate
systemctl mask transactional-update.service

# force ibus
echo 'export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus' >> /etc/skel/.profile

cp /etc/skel/.profile /home/deck/.profile
chown deck:deck /home/deck/.profile
