#!/bin/bash

set -xe

TEMP_PACKAGES="git rpm-build cargo cmake gcc-c++ fontconfig-devel rpm-build"

zypper -n --gpg-auto-import-keys install $TEMP_PACKAGES

# build and install some packages
cd /
git clone --depth 1 https://github.com/Kethen/opensuse_deck.git
cd opensuse_deck
cp rpmmacros ~/.rpmmacros
rpmbuild -bb deck-adaptation-for-opensuse.spec
zypper -n install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-adaptation-for-opensuse-0.1-0.x86_64.rpm
cd /
rm -r opensuse_deck

git clone --depth 1 https://github.com/Kethen/Simple-Steam-Deck-TDP-Slider.git
cd Simple-Steam-Deck-TDP-Slider
rpmbuild -bb deck-tdp-slider.spec
zypper -n install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-tdp-slider-0.1-0.x86_64.rpm
cd /
rm -rf Simple-Steam-Deck-TDP-Slider
rm -rf /root/.cargo

# install input methods and some fonts for fallback
set +e
zypper -n install 'google-noto-*' 'ibus-*'
status_code=$?
if [ "$status_code" != "107" ] && [ "$status_code" != "0" ]
then
	echo zypper -n install 'google-noto-*' 'ibus-*' exited with $status_code
	exit 1
fi
set -e

# copy screen orientation from opensuse_deck
tar -C / -cO etc/skel/.local/share/kscreen | tar -C /home/deck -xv
chown -R deck:deck /home/deck/.local

zypper -n remove --clean-deps $TEMP_PACKAGES

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

# toggle some services
systemctl enable NetworkManager
systemctl disable sshd
systemctl disable firewalld
