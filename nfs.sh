#!/bin/sh

NAME=gmetric_nfs
PROC_NFS=/proc/net/rpc/nfs
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

if [ ! -e $PROC_NFS ]; then
    echo "$NAME: $PROC_NFS doesn't seem to be exists."
    exit 1
fi

if [ ! -e $GMOND_LOCK ]; then
    echo "$NAME: gmond is not running."
    exit 1
fi

if [ -e $MY_LOCK ]; then
    echo "$NAME: $NAME is already running."
    exit 1
fi
touch $MY_LOCK

NFS_STATUS=(`cat $PROC_NFS | grep proc3`)

NFS_STATUS_GETATTR=${NFS_STATUS[3]}
$GMETRIC --name="nfs_getattr" --value="$NFS_STATUS_GETATTR" --type="uint16"

NFS_STATUS_READ=${NFS_STATUS[8]}
$GMETRIC --name="nfs_read" --value="$NFS_STATUS_READ" --type="uint16"

NFS_STATUS_WRITE=${NFS_STATUS[9]}
$GMETRIC --name="nfs_write" --value="$NFS_STATUS_WRITE" --type="uint16"

rm -f $MY_LOCK
