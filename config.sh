#!/bin/bash

set -xe

TEMP_PACKAGES="git rpm-build cargo cmake gcc-c++ fontconfig-devel rpm-build"

zypper -n --gpg-auto-import-keys install $TEMP_PACKAGES

cd /
git clone --depth 1 https://github.com/Kethen/opensuse_deck.git
cd opensuse_deck
cp rpmmacros ~/.rpmmacros
rpmbuild -bb deck-adaptation-for-opensuse.spec
zypper -n install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-adaptation-for-opensuse-0.1-0.x86_64.rpm

cd /
git clone --depth 1 https://github.com/Kethen/Simple-Steam-Deck-TDP-Slider.git
cd Simple-Steam-Deck-TDP-Slider
rpmbuild -bb deck-tdp-slider.spec
zypper -n install --allow-unsigned-rpm rpmbuild/rpms/x86_64/deck-tdp-slider-0.1-0.x86_64.rpm
rm -rf /root/.cargo

cd /
rm -rf opensuse_deck Simple-Steam-Deck-TDP-Slider

set +e
zypper -n install 'google-noto-*' 'ibus-*'
status_code=$?
if [ "$status_code" != "107" ] && [ "$status_code" != "0" ]
then
	echo zypper -n install 'google-noto-*' 'ibus-*' exited with $status_code
	exit 1
fi
set -e

zypper -n remove --clean-deps $TEMP_PACKAGES

zypper -n clean -a

passwd -l root
echo '%wheel  ALL=(ALL)       ALL' > /etc/sudoers.d/99_deck_pw_sudo
sed -iE '/^ALL   ALL=(ALL) ALL/d' /etc/sudoers
sed -iE '/^Defaults targetpw/d' /etc/sudoers

systemctl enable NetworkManager
