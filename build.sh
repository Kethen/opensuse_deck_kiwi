sudo bash -c '
set -ex

rm -rf image_out

while umount tmp_mnt
do
	echo unmount tmp_mnt
done

rm -rf tmp_mnt
mkdir -p tmp_mnt

mount -t tmpfs -o size=10G, tmpfs tmp_mnt


if ! kiwi-ng system prepare --description=./ --root=./tmp_mnt/kiwi_root_dir
then
	echo prepare failed, copying out root_dir for inspection
	rm -rf root_dir_debug
	tar -C ./tmp_mnt -cO kiwi_root_dir | tar -x
	mv kiwi_root_dir root_dir_debug
	exit 1
fi

kiwi-ng system create --root=./tmp_mnt/kiwi_root_dir --target-dir=./image_out

umount tmp_mnt
'
