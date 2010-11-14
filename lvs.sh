#!/bin/sh

VIPS="122.216.221.85:80"

NAME=gmetric_lvs
IPVSADM=/sbin/ipvsadm
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

if [ ! -e $IPVSADM ]; then
    echo "$NAME: $IPVSADM doesn't seem to be installed."
    exit 1
fi

if [ ! -e $GMOND_LOCK ]; then
    echo "$NAME: gmond is not running."
    exit 1
fi

if [ ! -e $LOCK_DIR/keepalived ]; then
    echo "$NAME: keepalived is not running."
    exit 1
fi

if [ -e $MY_LOCK ]; then
    echo "$NAME: $NAME is already running."
    exit 1
fi
touch $MY_LOCK

for vip in $VIPS
do
    LVS_CONNECTIONS=`$IPVSADM -L -c -n | grep $vip | grep ESTABLISHED | wc -l`
    if [ $LVS_CONNECTIONS -ge 0 ]; then
        $GMETRIC --name="lvs_connections_for_$vip" --value="$LVS_CONNECTIONS" --type="uint16" --units="Connections"
    fi
done

rm -f $MY_LOCK
