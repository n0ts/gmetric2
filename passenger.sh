#!/bin/sh

function kill_passenger_status()
{
    PASSENGER_STATUS_PID=`pgrep -f 'passenger-status'`
    if [ -n "$PASSENGER_STATUS_PID" ]; then
        for i in $PASSENGER_STATUS_PID
        do
            kill -9 $i
        done
        return 0
    fi

    return 1
}

NAME=gmetric_passenger
GMETRIC=/usr/bin/gmetric
GMETRIC_ARGS="--tmax=300"
LOCK_DIR=/var/lock/subsys
GMOND_LOCK=$LOCK_DIR/gmond
MY_LOCK=$LOCK_DIR/$NAME
PASSENGER_MEMORY_STATS=/opt/ruby/bin/passenger-memory-stats
PASSENGER_STATUS=/opt/ruby/bin/passenger-status
HTTPD=/usr/sbin/httpd.worker

if [ "x$1" == "x--clean" ]; then
    if [ -f $MY_LOCK ]; then
        rm -f $MY_LOCK
    fi
    exit 0
fi

if [ ! -e $PASSENGER_MEMORY_STATS -o ! -e $PASSENGER_STATUS ]; then
    echo "$NAME: passenger doesn't seem to be installed."
    exit 1
fi

if [ -f /etc/sysconfig/httpd ]; then
    . /etc/sysconfig/httpd
fi
export HTTPD=$HTTPD

if [ ! -e $GMETRIC ]; then
    echo "$NAME: $GMETRIC doesn't seem to be installed."
    exit 1
fi
GMETRIC="$GMETRIC $GMETRIC_ARGS"

if [ ! -e $LOCK_DIR/httpd ]; then
    echo "$NAME: httpd is not running."
    exit 1
fi

if [ ! -e $GMOND_LOCK ]; then
    echo "$NAME: gmond is not running."
    exit 1
fi

if [ -e $MY_LOCK ]; then
    kill_passenger_status
    RETVAL=$?
    if [ $RETVAL == 0 ]; then
        rm -f $MY_LOCK
    fi
    echo "$NAME: $NAME is already running."
    exit 1
fi
touch $MY_LOCK

PASSENGER_MEMORY_STATS=`$PASSENGER_MEMORY_STATS`

OLD_IFS=$IFS
IFS='
'
APACHE_MODE=1
for i in $PASSENGER_MEMORY_STATS
do
    PASSENGER_MEMORY_STATS_NAME=`echo $i | cut -d ':' -f 1`
    if [ $PASSENGER_MEMORY_STATS_NAME = "### Processes" ]; then
        value=`echo $i | cut -d ':' -f 2 | tr -d ' '`
        if [ $APACHE_MODE = 1 ]; then
            APACHE_PROCESSES=$value
        else
            PASSENGER_PROCESSES=$value
        fi
    elif [ $PASSENGER_MEMORY_STATS_NAME = "### Total private dirty RSS" ]; then
        value=`echo $i | cut -d ':' -f 2 | tr -d [MB] | tr -d ' '`
        if [ $APACHE_MODE = 1 ]; then
            APACHE_MODE=0
            APACHE_RSS=$value
        else
            PASSENGER_RSS=$value
        fi
    fi
done
IFS=$OLD_IFS

$GMETRIC --name="passenger_apache_processes" --value="$APACHE_PROCESSES" --type="uint16" --units="Processes"
$GMETRIC $APACHE_RSS --name="passenger_apache_rss" --value="$APACHE_RSS" --type="float" --units="MB"
$GMETRIC --name="passenger_passenger_processes" --value="$PASSENGER_PROCESSES" --type="uint16" --units="Processes"
$GMETRIC --name="passenger_rss" --value="$PASSENGER_RSS" --type="float" --units="MB"


kill_passenger_status
PASSENGER_STATUS=`$PASSENGER_STATUS`

OLD_IFS=$IFS
IFS='
'
for i in $PASSENGER_STATUS
do
    PASSENGER_STATUS_NAME=`echo $i | cut -d '=' -f 1 | tr -d ' '`
    case $PASSENGER_STATUS_NAME in
        'max')
        PASSENGER_STATUS_MAX=`echo $i | cut -d '=' -f 2 | tr -d ' '`
        ;;
        'count')
        PASSENGER_STATUS_COUNT=`echo $i | cut -d '=' -f 2 | tr -d ' '`
        ;;
        'active')
        PASSENGER_STATUS_ACTIVE=`echo $i | cut -d '=' -f 2 | tr -d ' '`
        ;;
        'inactive')
        PASSENGER_STATUS_INACTIVE=`echo $i | cut -d '=' -f 2 | tr -d ' '`
        break
        ;;
    esac
done
IFS=$OLD_IFS

$GMETRIC --name="passenger_status_max" --value="$PASSENGER_STATUS_MAX" --type="uint16" --units="Instances"
$GMETRIC --name="passenger_status_count" --value="$PASSENGER_STATUS_COUNT" --type="uint16" --units="Instances"
$GMETRIC --name="passenger_status_active" --value="$PASSENGER_STATUS_ACTIVE" --type="uint16" --units="Instances"
$GMETRIC --name="passenger_status_inactive" --value="$PASSENGER_STATUS_INACTIVE" --type="uint16" --units="Instances"

rm -f $MY_LOCK
