#!/bin/bash

ARCH=$(uname -m)

elilotest=""
lilotest=""
grubtest=""
zipltest=""
yaboottest=""

case "$ARCH" in
    i?86)
	lilotest="yes"
	grubtest="yes"
	;;
    x86_64)
	lilotest="yes"
	grubtest="yes"
	;;
    ppc*)
	yaboottest="yes"
	;;
    s390*)
	zipltest="yes"
	;;
    *)
	echo "Not running any tests for $ARCH"
	exit 0
esac

export MALLOC_CHECK_=2

RESULT=0

oneTest () {
    mode=$1
    cfg=test/$2
    correct=test/results/$3
    shift; shift; shift
    ./grubby $mode --bad-image-okay -c $cfg -o - "$@" | cmp $correct > /dev/null

    if [ $? != 0 ]; then 
	echo -------------------------------------------------------------
	echo FAILURE: $cfg $correct "$@"
	echo -n ./grubby $mode --bad-image-okay -c $cfg -o - 
	for arg in "$@"; do
	    echo -n " \"$arg\""
	done
	echo ""
	./grubby $mode --bad-image-okay -c $cfg -o - "$@" | diff -u $correct -; 
	RESULT=1
    fi 
}

liloTest() {
    if [ -z "$lilotest" ]; then echo "skipping LILO test" ; return; fi
    oneTest --lilo "$@"
}

eliloTest() {
    if [ -z "$elilotest" ]; then echo "skipping ELILO test" ; return; fi
    oneTest --elilo "$@"
}

grubTest() {
    if [ -z "$grubtest" ]; then echo "skipping GRUB test" ; return; fi
    oneTest --grub "$@"
}

yabootTest() {
    if [ -z "$yaboottest" ]; then echo "skipping YABOOT test" ; return; fi
    oneTest --yaboot "$@"
}

ziplTest() {
    if [ -z "$zipltest" ]; then echo "skipping Z/IPL test" ; return; fi
    oneTest --zipl "$@"
}

echo "Parse/write comparison..."
for n in $(cd test; echo grub.[0-9]*); do
    grubTest $n ../$n --remove-kernel 1234
done

for n in $(cd test; echo lilo.[0-9]*); do
    liloTest $n ../$n --remove-kernel 1234
done

echo "Permission preservation..."
cp test/grub.1 grub-test
chmod 0614 grub-test 
touch -t 200301010101.00 grub-test
time=$(ls -l grub-test | awk '{ print $6 " " $7 " "$8}')
perm=$(ls -l grub-test | awk '{print $1}')
./grubby --grub --add-kernel bar --title title -c grub-test 
newtime=$(ls -l grub-test | awk '{ print $6 " " $7 " "$8}')
newperm=$(ls -l grub-test | awk '{print $1}')
if [ "$time" == "$newtime" -o "$perm" != "$newperm" ]; then
    echo "  failed ($perm $newperm)"; 
fi
rm -f grub-test

cp test/lilo.1 lilo-test
chmod 0614 lilo-test 
touch -t 200301010101.00 lilo-test
time=$(ls -l lilo-test | awk '{ print $6 " " $7 " "$8}')
perm=$(ls -l lilo-test | awk '{print $1}')
./grubby --lilo --add-kernel bar --title title -c lilo-test 
newtime=$(ls -l lilo-test | awk '{ print $6 " " $7 " "$8}')
newperm=$(ls -l lilo-test | awk '{print $1}')
if [ "$time" == "$newtime" -o "$perm" != "$newperm" ]; then
    echo "  failed ($perm $newperm)"; 
fi
rm -f lilo-test

echo "Following symlinks..."
cp test/grub.1 grub-test
ln -s grub-test mytest
./grubby --grub --add-kernel bar --title title -c mytest
if [ ! -L mytest ]; then
    echo " failed (not a symlink)"
fi
target=$(ls -l mytest | awk '{ print $11 }')
if [ "$target" != grub-test ]; then
    echo "  failed (wrong target)"
fi
rm -f grub-test mytest

echo "GRUB default directive..."
grubTest grub.1 default/g1.1 --boot-filesystem=/boot --add-kernel /boot/new-kernel --title Some_Title 
grubTest grub.1 default/g1.2 --boot-filesystem=/boot --add-kernel /boot/new-kernel --title Some_Title --make-default
grubTest grub.3 default/g3.1 --boot-filesystem=/boot --set-default=/boot/vmlinuz-2.4.7-2
grubTest grub.3 default/g3.2 --boot-filesystem=/boot --set-default=/boot/vmlinuz-2.4.7-2smp
grubTest grub.4 default/g4.1 --boot-filesystem=/ --set-default=/boot/vmlinuz-2.4.7-ac3 --remove-kernel /boot/vmlinuz-2.4.7-2.5
grubTest grub.4 default/g4.2 --boot-filesystem=/ --set-default=/boot/vmlinuz-2.4.7-ac3 --remove-kernel /boot/vmlinuz-2.4.7-2.5 --add-kernel=/boot/new-kernel --copy-default --title New_Title
grubTest grub.6 default/g6.1 --remove-kernel=/boot/vmlinuz-2.4.7-2.9 --boot-filesystem=/

echo "LILO default directive..."
liloTest lilo.1 default/l1.1 --set-default=/boot/vmlinuz-2.4.18-4
liloTest lilo.1 default/l1.2 --remove-kernel=/boot/vmlinuz-2.4.18-4smp
liloTest lilo.1 default/l1.3 --add-kernel /boot/kernel --title label \
    --copy-default
liloTest lilo.1 default/l1.4 --add-kernel /boot/kernel --title label \
    --copy-default --make-default

echo "Z/IPL default directive..."
ziplTest zipl.1 default/z1.1 --add-kernel /boot/new-kernel --title test
ziplTest zipl.1 default/z1.2 --add-kernel /boot/new-kernel --title test --make-default

echo "GRUB fallback directive..."
grubTest grub.5 fallback/g5.1 --remove-kernel=/boot/vmlinuz-2.4.7-ac3 \
    --boot-filesystem=/
grubTest grub.5 fallback/g5.2 --remove-kernel=/boot/vmlinuz-2.4.7-2.5 \
    --boot-filesystem=/
grubTest grub.5 fallback/g5.3 --remove-kernel=/boot/vmlinuz-2.4.7-2.5 \
    --boot-filesystem=/ --copy-default --add-kernel=/boot/new-kernel \
    --title="Some_Title"

echo "GRUB new kernel argument handling..."
grubTest grub.1 args/g1.1 --boot-filesystem=/boot \
    --add-kernel=/boot/foo --title=some_title --args="1234" --copy-default
grubTest grub.1 args/g1.2 --boot-filesystem=/boot \
    --add-kernel=/boot/foo --title=some_title --args="1234" 

echo "GRUB remove kernel..."
grubTest grub.7 remove/g7.1 --boot-filesystem=/ \
    --remove-kernel=/boot/vmlinuz-2.4.7-2.5
grubTest grub.3 remove/g3.1 --boot-filesystem=/ \
    --remove-kernel=DEFAULT
grubTest grub.9 remove/g9.1 --boot-filesystem=/boot \
    --remove-kernel=/boot/vmlinuz-2.4.7-2

echo "YABOOT remove kernel..."
yabootTest yaboot.1 remove/y1.1 --boot-filesystem=/ --remove-kernel=DEFAULT
yabootTest yaboot.1 remove/y1.2 --boot-filesystem=/ --remove-kernel=/boot/vmlinuz-2.5.50-eepro
yabootTest yaboot.2 remove/y2.1 --boot-filesystem=/ --remove-kernel=/boot/vmlinux-2.5.50

echo "Z/IPL remove kernel..."
ziplTest zipl.1 remove/z1.1 --remove-kernel=/boot/vmlinuz-2.4.9-38
ziplTest zipl.1 remove/z1.2 --remove-kernel=DEFAULT

echo "GRUB update kernel argument handling..."
grubTest grub.1 updargs/g1.1 --update-kernel=DEFAULT --args="root=/dev/hda1"
grubTest grub.1 updargs/g1.2 --update-kernel=DEFAULT \
    --args="root=/dev/hda1 hda=ide-scsi root=/dev/hda2"
grubTest grub.3 updargs/g3.1 --update-kernel=DEFAULT --args "hdd=notide-scsi"
grubTest grub.3 updargs/g3.2 --update-kernel=DEFAULT \
    --args "hdd=notide-scsi root=/dev/hdd1"
grubTest grub.3 updargs/g3.2 --update-kernel=DEFAULT \
    --args "root=/dev/hdd1 hdd=notide-scsi"
grubTest grub.3 updargs/g3.4 --update-kernel=ALL --remove-args="hdd"
grubTest grub.3 updargs/g3.4 --update-kernel=ALL --remove-args="hdd=ide-scsi"
grubTest grub.3 updargs/g3.4 --update-kernel=ALL --remove-args="hdd=foobar"
grubTest grub.3 updargs/g3.7 --update-kernel=ALL \
    --remove-args="hdd root ro"
grubTest grub.7 updargs/g7.2 --boot-filesystem=/    \
    --update-kernel=ALL --args "hde=ide-scsi"
grubTest grub.7 updargs/g7.2 --boot-filesystem=/    \
    --update-kernel=ALL --args "hde=ide-scsi"
grubTest grub.7 updargs/g7.3 --boot-filesystem=/    \
    --update-kernel=DEFAULT --args "hde=ide-scsi"

echo "LILO update kernel argument handling..."
liloTest lilo.1 updargs/l1.1 --update-kernel=/boot/vmlinuz-2.4.18-4 \
    --args="root=/dev/md1"
liloTest lilo.1 updargs/l1.2 --update-kernel=/boot/vmlinuz-2.4.18-4smp \
    --args="root=LABEL=foo"
liloTest lilo.1 updargs/l1.3 --update-kernel=DEFAULT --args="foo"
liloTest lilo.1 updargs/l1.4 --update-kernel=ALL --args="foo bar root=/dev/md1"
liloTest lilo.1 updargs/l1.4 --update-kernel=ALL --args="foo root=/dev/md1 bar"
liloTest lilo.1 updargs/l1.6 --update-kernel=ALL --args="foo root=LABEL=/ bar"
liloTest lilo.3 updargs/l3.1 --update-kernel=/boot/vmlinuz-2.4.18-4 \
    --remove-args="hda"
liloTest lilo.3 updargs/l3.2 --update-kernel=ALL \
    --remove-args="single" --args "root=/dev/hda2"

echo "LILO add kernel..."
liloTest lilo.4 add/l4.1 --add-kernel=/boot/new-kernel.img --title="title" \
    --copy-default --boot-filesystem=/boot
liloTest lilo.4 add/l4.2 --add-kernel=/boot/new-kernel.img --title="linux" \
    --copy-default --boot-filesystem=/boot --remove-kernel "TITLE=linux"
liloTest lilo.5 add/l5.1 --add-kernel=/boot/new-kernel.img --title="title" \
    --copy-default --boot-filesystem=/boot
liloTest lilo.5 add/l5.2 --add-kernel=/boot/new-kernel.img --title="linux" \
    --copy-default --boot-filesystem=/boot --remove-kernel "TITLE=linux"
liloTest lilo.6 add/l6.1 --add-kernel=/boot/new-kernel.img --title="title" \
  --initrd=/boot/new-initrd  --copy-default --boot-filesystem=/boot
liloTest lilo.6 add/l6.2 --add-kernel=/boot/new-kernel.img --title="linux" \
  --initrd=/boot/new-initrd --copy-default --boot-filesystem=/boot --remove-kernel "TITLE=linux"


echo "GRUB add kernel..."
grubTest grub.1 add/g1.1 --add-kernel=/boot/new-kernel.img --title='title' \
    --initrd=/boot/new-initrd --boot-filesystem=/
grubTest grub.1 add/g1.2 --add-kernel=/boot/new-kernel.img --title='title' \
    --initrd=/boot/new-initrd --boot-filesystem=/boot
grubTest grub.1 add/g1.3 --add-kernel=/boot/new-kernel.img --title='title' \
    --initrd=/boot/new-initrd --boot-filesystem=/ --copy-default
grubTest grub.1 add/g1.4 --add-kernel=/boot/new-kernel.img --title='title' \
    --initrd=/boot/new-initrd --boot-filesystem=/boot --copy-default
grubTest grub.2 add/g2.1 --add-kernel=/boot/vmlinuz-2.4.7-2	    \
    --initrd=/boot/initrd-2.4.7-new.img --boot-filesystem=/boot --copy-default \
    --title="Red Hat Linux (2.4.7-2)"					    \
    --remove-kernel="TITLE=Red Hat Linux (2.4.7-2)" 
grubTest grub.8 add/g8.1 --add-kernel=/boot/new-kernel.img --title='title' \
    --initrd=/boot/new-initrd --boot-filesystem=/boot --copy-default

echo "YABOOT add kernel..."
yabootTest yaboot.1 add/y1.1 --copy-default --boot-filesystem=/ --add-kernel=/boot/new-kernel  \
    --title=newtitle
yabootTest yaboot.1 add/y1.2 --add-kernel=/boot/new-kernel --boot-filesystem=/ --title=newtitle

echo "YABOOT empty label..."
yabootTest yaboot.3 add/y3.1 --add-kernel=/boot/new-kernel --boot-filesystem=/ --title=newtitle

echo "Z/IPL add kernel..."
ziplTest zipl.1 add/z1.1 --add-kernel=/boot/new-kernel.img --title test
ziplTest zipl.1 add/z1.2 --add-kernel=/boot/new-kernel.img --title test --copy-default

echo "LILO long titles..."
liloTest lilo.1 longtitle/l1.1 --add-kernel=/boot/new-kernel.img \
    --title="linux-longtitle" --copy-default --boot-filesystem=/boot 
liloTest lilo.1 longtitle/l1.2 --add-kernel=/boot/new-kernel.img \
    --title="linux-toolongtitle" --copy-default --boot-filesystem=/boot 
liloTest lilo.7 longtitle/l7.1 --add-kernel=/boot/new-kernel.img \
    --title="linux-longtitle-fix" --copy-default --boot-filesystem=/boot 

echo "ELILO long titles..."
eliloTest lilo.7 longtitle/e7.1 --add-kernel=/boot/new-kernel.img \
    --title="linux-longtitle-fix" --copy-default --boot-filesystem=/boot 

echo "GRUB add multiboot..."
grubTest grub.1 multiboot/g1.1 --add-multiboot=/boot/xen.gz \
    --add-kernel=/boot/vmlinuz-2.6.10-1.1088_FC4 --boot-filesystem=/boot \
    --initrd=/boot/initrd-2.6.10-1.1088_FC4.img --title foo \
    --mbargs="dom0_mem=130000"
grubTest grub.1 multiboot/g1.2 --add-multiboot=/boot/xen.gz \
    --add-kernel=/boot/vmlinuz-2.6.10-1.1088_FC4 --boot-filesystem=/boot \
    --initrd=/boot/initrd-2.6.10-1.1088_FC4.img --title foo \
    --mbargs="dom0_mem=130000" --copy-default
grubTest grub.10 multiboot/g10.1 --add-multiboot=/boot/xen.gz \
    --add-kernel=/boot/vmlinuz-2.6.10-1.1088_FC4 --boot-filesystem=/boot \
    --initrd=/boot/initrd-2.6.10-1.1088_FC4.img --title foo \
    --mbargs="dom0_mem=130000"
grubTest grub.10 multiboot/g10.2 --add-multiboot=/boot/xen.gz \
    --add-kernel=/boot/vmlinuz-2.6.10-1.1088_FC4 --boot-filesystem=/boot \
    --initrd=/boot/initrd-2.6.10-1.1088_FC4.img --title foo \
    --mbargs="dom0_mem=130000" --copy-default
grubTest grub.10 multiboot/g10.3 --add-kernel=/boot/vmlinuz-2.6.10-1.1088_FC4 \
    --initrd=/boot/initrd-2.6.10-1.1088_FC4.img --title foo \
    --copy-default --boot-filesystem=/boot
grubTest grub.10 multiboot/g10.4 --add-kernel=/boot/vmlinuz-2.6.10-1.1088_FC4 \
    --initrd=/boot/initrd-2.6.10-1.1088_FC4.img --title foo \
    --boot-filesystem=/boot

echo "GRUB remove multiboot..."
grubTest grub.10 multiboot/g10.5 --boot-filesystem=/boot \
    --remove-kernel=/boot/vmlinuz-2.6.10-1.1076_FC4
grubTest grub.10 multiboot/g10.6 --boot-filesystem=/boot \
    --remove-kernel=/boot/vmlinuz-2.6.10-1.1082_FC4
grubTest grub.10 multiboot/g10.7 --boot-filesystem=/boot \
    --remove-multiboot=/boot/xen.gz

exit $RESULT
