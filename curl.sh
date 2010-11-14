#!/bin/sh

URLS="<%= target_url %>"
URLS_NAME="<%= gmetric_url_name %>"

NAME=gmetric_curl
CURL=/usr/bin/curl
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

if [ ! -e $CURL ]; then
    echo "$NAME: $CURL doesn't seem to be installed."
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

count=0
for url in $URLS
do
    CURL_TOTAL_TIME=`$CURL -w '%{time_total}\n' -o /dev/null -s $url`
    $GMETRIC --name="${URLS_NAME[$count]}" --value="$CURL_TOTAL_TIME" --type="float" --units="Seconds"
    count=`expr $count + 1`
done

rm -f $MY_LOCK
