sudo bash -c '
set -ex

rm -rf image_out

#BUILD_TARGETS="with-KDE with-GNOME with-KDE-nvidia with-GNOME-nvidia"
#BUILD_TARGETS="with-KDE with-GNOME"
BUILD_TARGETS="with-KDE"

for profile in $BUILD_TARGETS
do

	while umount tmp_mnt
	do
		echo unmount tmp_mnt
	done

	rm -rf tmp_mnt
	mkdir -p tmp_mnt

	mount -t tmpfs -o size=10G, tmpfs tmp_mnt


	if ! python3 /usr/bin/kiwi-ng --debug --profile=$profile system prepare --description=./ --root=./tmp_mnt/kiwi_root_dir
	then
		echo prepare failed, copying out root_dir for inspection
		rm -rf root_dir_debug
		tar -C ./tmp_mnt -cO kiwi_root_dir | tar -x
		mv kiwi_root_dir root_dir_debug
		exit 1
	fi

	python3 /usr/bin/kiwi-ng --profile=$profile system create --root=./tmp_mnt/kiwi_root_dir --target-dir=./image_out/$profile/
	umount tmp_mnt
done
'
