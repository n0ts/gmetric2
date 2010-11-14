#!/bin/sh

NAME=gmetric_apache
WGET=/usr/bin/wget
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

if [ ! -e $WGET ]; then
    echo "$NAME: $WGET doesn't seem to be installed."
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


scoreboard_gmetric()
{
    NAME=$1
    STATUS_CHAR=$2

    VALUE=`echo $APACHE_STATUS_SCOREBOARD | sed -e s/[^$STATUS_CHAR]//g | wc -m`
    VALUE=`expr $VALUE - 1`
    $GMETRIC --name="$NAME" --value="$VALUE" --type="uint16"
}


APACHE_STATUS=`$WGET --header='Host: status.<%= fqdn %>' -q -O - http://localhost/server-status/?auto`

OLD_IFS=$IFS
IFS='
'
for i in $APACHE_STATUS; do
    APACHE_STATUS_NAME=`echo $i | cut -d ':' -f 1`
    IFS=' '
    case $APACHE_STATUS_NAME in
    'CPULoad')
        APACHE_STATUS_CPU_LOAD=`echo $i | cut -d ':' -f 2`
        ;;
    'ReqPerSec')
        APACHE_STATUS_REQ_PER_SEC=`echo $i | cut -d ':' -f 2`
        ;;
    'BytesPerSec')
        APACHE_STATUS_BYTES_PER_SEC=`echo $i | cut -d ':' -f 2`
        ;;
    'BusyWorkers')
        APACHE_STATUS_BUSY_WORKERS=`echo $i | cut -d ':' -f 2`
        ;;
    'IdleWorkers')
        APACHE_STATUS_IDLE_WORKERS=`echo $i | cut -d ':' -f 2`
        ;;
    'Scoreboard')
        APACHE_STATUS_SCOREBOARD=`echo $i | cut -d ':' -f 2`
        ;;
    esac
done
IFS=$OLD_IFS

if [ -n $APACHE_STATUS_CPU_LOAD ]; then
    $GMETRIC --name="apache_cpu_load" --value="$APACHE_STATUS_CPU_LOAD" --type="float"
fi

if [ -n $APACHE_STATUS_REQ_PER_SEC ]; then
    $GMETRIC --name="apache_req_per_sec" --value="$APACHE_STATUS_REQ_PER_SEC" --type="float" --units="Request/sec"
fi

if [ -n $APACHE_STATUS_BYTES_PER_SEC ]; then
    $GMETRIC --name="apache_bytes_per_sec" --value="$APACHE_STATUS_BYTES_PER_SEC" --type="float" --units="Bytes/sec"
fi

if [ -n $APACHE_STATUS_BUSY_WORKERS ]; then
    $GMETRIC --name="apache_busy_workers" --value="$APACHE_STATUS_BUSY_WORKERS"  --type="uint16"
fi

if [ -n $APACHE_STATUS_IDLE_WORKERS ]; then
    $GMETRIC --name="apache_idle_workers" --value="$APACHE_STATUS_IDLE_WORKERS" --type="uint16"
fi

if [ -n $APACHE_STATUS_SCOREBOARD ]; then
    scoreboard_gmetric "apache_scoreboard_waiting" "_"
    scoreboard_gmetric "apache_scoreboard_starting" "S"
    scoreboard_gmetric "apache_scoreboard_reading_request" "R"
    scoreboard_gmetric "apache_scoreboard_sending_reply" "W"
    scoreboard_gmetric "apache_scoreboard_keepalive" "K"
    scoreboard_gmetric "apache_scoreboard_dns_lookup" "D"
    scoreboard_gmetric "apache_scoreboard_closing" "C"
    scoreboard_gmetric "apache_scoreboard_logging" "L"
    scoreboard_gmetric "apache_scoreboard_gracefully_finishing" "L"
    scoreboard_gmetric "apache_scoreboard_idle" "I"
fi

rm -f $MY_LOCK
