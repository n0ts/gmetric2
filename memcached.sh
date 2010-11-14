#!/bin/sh

NAME=gmetric_memcached
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

if [ ! -e $LOCK_DIR/memcached ]; then
    echo "$NAME: memcached is not running."
    exit 1
fi

if [ -e $MY_LOCK ]; then
    echo "$NAME: $NAME is already running."
    exit 1
fi
touch $MY_LOCK


MEMCACHED_STATUS=`echo -ne "stats\r\n" | nc -w 1 localhost 11211`
if [ -z "$MEMCACHED_STATUS" ]; then
    echo "$NAME: Could not get memcached infromation."
    exit 1
fi

OLD_IFS=$IFS
IFS='
'
for i in $MEMCACHED_STATUS; do
    MEMCACHED_STATUS_NAME=`echo $i | cut -d ' ' -f 2`
    case $MEMCACHED_STATUS_NAME in
        'bytes')
            MEMCACHED_STATUS_BYTES=`echo $i | tr -c -d [0-9]`
            ;;
        'cmd_get')
            MEMCACHED_STATUS_CMD_GET=`echo $i | tr -c -d [0-9]`
            ;;
        'cmd_set')
            MEMCACHED_STATUS_CMD_SET=`echo $i | tr -c -d [0-9]`
            ;;
        'curr_connections')
            MEMCACHED_STATUS_CURR_CONNECTIONS=`echo $i | tr -c -d [0-9]`
            ;;
        'curr_items')
            MEMCACHED_STATUS_CURR_ITEMS=`echo $i | tr -c -d [0-9]`
            ;;
        'get_hits')
            MEMCACHED_STATUS_GET_HITS=`echo $i | tr -c -d [0-9]`
            ;;
        'get_misses')
            MEMCACHED_STATUS_GET_MISSES=`echo $i | tr -c -d [0-9]`
            ;;
        'limit_maxbytes')
            MEMCACHED_STATUS_LIMIT_MAXBYTES=`echo $i | tr -c -d [0-9]`
            ;;
        'uptime')
            MEMCACHED_STATUS_UPTIME=`echo $i | tr -c -d [0-9]`
            ;;
    esac
done
IFS=$OLD_IFS

if [ $MEMCACHED_STATUS_BYTES -gt 0 ]; then
    $GMETRIC --name="memcached_bytes" --value="$MEMCACHED_STATUS_BYTES" --type="uint32" --units="Bytes"
    $GMETRIC --name="memcached_curr_connections" --value="$MEMCACHED_STATUS_CURR_CONNECTIONS" --type="uint32" --units="Connections"
    $GMETRIC --name="memcached_curr_items" --value="$MEMCACHED_STATUS_CURR_ITEMS" --type="uint32" --units="Items"
    $GMETRIC --name="memcached_limit_maxbytes" --value="$MEMCACHED_STATUS_LIMIT_MAXBYTES" --type="uint32" --units="Bytes" --slope="zero"
    MEMCACHED_STATUS_CACHE_HITS=`echo "scale=4; ($MEMCACHED_STATUS_GET_HITS / ($MEMCACHED_STATUS_GET_HITS + $MEMCACHED_STATUS_GET_MISSES)) * 100" | bc`
    MEMCACHED_STATUS_CACHE_HITS=`printf "%.02f" $MEMCACHED_STATUS_CACHE_HITS`
    $GMETRIC --name="memcached_cache_hits" --value="$MEMCACHED_STATUS_CACHE_HITS" --type="float" --units="%"
    MEMCACHED_STATUS_CACHE_MISSES=`echo "scale=4; ($MEMCACHED_STATUS_GET_MISSES / ($MEMCACHED_STATUS_GET_HITS + $MEMCACHED_STATUS_GET_MISSES)) * 100" | bc`
    MEMCACHED_STATUS_CACHE_MISSES=`printf "%.02f" $MEMCACHED_STATUS_CACHE_MISSES`
    $GMETRIC --name="memcached_cache_misses" --value="$MEMCACHED_STATUS_CACHE_MISSES" --type="float" --units="%"

    MEMCACHED_STATUS_GET_PER_SEC=`expr $MEMCACHED_STATUS_CMD_GET / $MEMCACHED_STATUS_UPTIME`
    $GMETRIC --name="memcached_get_per_sec" --value="$MEMCACHED_STATUS_GET_PER_SEC" --type="uint32"

    MEMCACHED_STATUS_SET_PER_SEC=`expr $MEMCACHED_STATUS_CMD_SET / $MEMCACHED_STATUS_UPTIME`
    $GMETRIC --name="memcached_set_per_sec" --value="$MEMCACHED_STATUS_SET_PER_SEC" --type="uint32"
fi

rm -f $MY_LOCK
