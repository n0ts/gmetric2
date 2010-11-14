#!/bin/sh

DEVICES="sda sdb"

NAME=gmetric_iostat
GMETRIC=/usr/bin/gmetric
GMETRIC_ARGS=
LOCK_DIR=/var/lock/subsys
GMOND_LOCK=$LOCK_DIR/gmond
MY_LOCK=$LOCK_DIR/$NAME

if [ "x$1" == "x--clean" ]; then
    if [ -f $MY_LOCK ]; then
        rm -f $MY_LOCK
    fi
    exit 0
fi

if [ ! -e $GMETRIC ]; then
    echo "$NAME: $GMETRIC doesn't seem to be installed."
    exit 1
fi
GMETRIC="$GMETRIC $GMETRIC_ARGS"

if [ ! -e $GMOND_LOCK ]; then
    echo "$NAME: gmond is not running."
    exit 1
fi

if [ -e $MY_LOCK ]; then
    echo "$NAME: $NAME is already running."
    exit 1
fi
touch $MY_LOCK

for device in $DEVICES
do
    IOSTAT=(`/usr/bin/iostat -d -x $device | grep $device`)

    if [ -z "$IOSTAT" ]; then
        continue
    fi

    IOSTAT_AVGRQ_SZ=${IOSTAT[7]}
    $GMETRIC --name="iostat_avgrq_sz_${device}" --value="$IOSTAT_AVGRQ_SZ" --type="float" --units="queue"

    IOSTAT_AWAIT=${IOSTAT[8]}
    $GMETRIC --name="iostat_await_${device}" --value="$IOSTAT_AWAIT" --type="float" --units="sec"

    IOSTAT_UTIL=${IOSTAT[11]}
    $GMETRIC --name="iostat_util_${device}" --value="$IOSTAT_UTIL" --type="float" --units="%"
done

rm -f $MY_LOCK
