#!/bin/sh

NAME=gmetric_mysql
MYSQL=/usr/bin/mysql
SOCKET=/var/lib/mysql/mysql.sock
GMETRIC=/usr/bin/gmetric
GMETRIC_ARGS=
GMETRIC_NAME_HEADER=mysql
LOCK_DIR=/var/lock/subsys
GMOND_LOCK=$LOCK_DIR/gmond
MY_LOCK=$LOCK_DIR/$NAME
TMP_DIR=/tmp/$NAME

if [ "x$1" == "x--clean" ]; then
    if [ -d $TMP_DIR ]; then
        rm -fr $TMP_DIR
    fi
    if [ -f $MY_LOCK ]; then
        rm -f $MY_LOCK
    fi
    exit 0
fi

if [ ! -e $GMETRIC ]; then
    echo "$NAME: gmetric doesn't seem to be installed."
    exit 1
fi
GMETRIC="$GMETRIC $GMETRIC_ARGS"

if [ ! -e $MYSQL ]; then
    echo "$NAME: $MYSQL doesn't seem to be installed."
    exit 1
fi

if [ ! -e $GMOND_LOCK ]; then
    echo "$NAME: gmond is not running."
    exit 1
fi

if [ ! -e $LOCK_DIR/mysqld ]; then
    echo "$NAME: mysqld is not runnig."
    exit 1
fi

if [ -e $MY_LOCK ]; then
    echo "$NAME: $NAME is already running."
    exit 1
fi
touch $MY_LOCK


get_status_value()
{
    NAME=$1

    MYSQL_STATUS=`$MYSQL -u root -S $SOCKET --connect_timeout=1 -e "show global status like '$NAME'" | tail -1`
    VALUE=`echo $MYSQL_STATUS | cut -d ' ' -f 2`
}

get_variable_value()
{
    NAME=$1

    MYSQL_STATUS=`$MYSQL -u root -S $SOCKET --connect_timeout=1 -e "show variables like '$NAME'" | tail -1`
    VALUE=`echo $MYSQL_STATUS | cut -d ' ' -f 2`
}

calc_status_gmetric()
{
    NAME=$1
    GMETRIC_NAME=${GMETRIC_NAME_HEADER}_${2}
    GMETRIC_TYPE=$3
    GMETRIC_UNIT=$4

    get_status_value $NAME

    TMP_FILE=$TMP_DIR/$NAME
    if [ -f $TMP_FILE ]; then
        LAST_VALUE=`cat $TMP_FILE`
        CALC_VALUE=`expr $VALUE - $LAST_VALUE`
        if [ $CALC_VALUE -le 0 ]; then
            CALC_VALUE=0
        fi

        $GMETRIC --name="$GMETRIC_NAME" --value="$CALC_VALUE" --type="$GMETRIC_TYPE" --units="$GMETRIC_UNIT"
    fi

    echo $VALUE > $TMP_DIR/$NAME
}


if [ ! -d $TMP_DIR ]; then
    mkdir $TMP_DIR
fi

calc_status_gmetric "Bytes_received" "bytes_received" "uint32" "Bytes"
calc_status_gmetric "Bytes_sent" "bytes_sent" "uint32" "Bytes"

calc_status_gmetric "Com_delete" "com_delete" "uint32" "Queries"
calc_status_gmetric "Com_insert" "com_insert" "uint32" "Queries"
calc_status_gmetric "Com_select" "com_select" "uint32" "Queries"
calc_status_gmetric "Com_update" "com_update" "uint32" "Queries"

calc_status_gmetric "Connections" "connections" "uint32" "Connections"
MYSQL_CONNECTIONS=$VALUE

calc_status_gmetric "Questions" "questions" "uint32" "Queries"
MYSQL_QUESTIONS=$VALUE

get_status_value "Threads_cached"
$GMETRIC --name="${GMETRIC_NAME_HEADER}_threads_cached" --value="$VALUE" --type="uint16"  --units="Threads"

get_status_value "Threads_connected"
$GMETRIC --name="${GMETRIC_NAME_HEADER}_threads_connected" --value="$VALUE" --type="uint16" --units="Connections"

calc_status_gmetric "Threads_created" "threads_created" "uint32" "Threads"
MYSQL_THREADS_CREATED=$VALUE

get_status_value "Threads_running"
$GMETRIC --name="${GMETRIC_NAME_HEADER}_threads_running" --value="$VALUE" --type="uint16" --units="Threads"

get_status_value "Key_reads"
MYSQL_KEY_READS=$VALUE
get_status_value "Key_read_requests"
MYSQL_KEY_READ_REQUESTS=$VALUE
if [ $MYSQL_KEY_READ_REQUESTS -gt 0 ]; then
    MYSQL_KEY_CACHE_HITS=`echo "scale=4; 100 - (($MYSQL_KEY_READS / $MYSQL_KEY_READ_REQUESTS) * 100)" | bc`
    MYSQL_KEY_CACHE_HITS=`printf "%.02f" $MYSQL_KEY_CACHE_HITS`
    $GMETRIC --name="${GMETRIC_NAME_HEADER}_key_cache_hits" --value="$MYSQL_KEY_CACHE_HITS" --type="float" --units="%"
fi

get_status_value "Qcache_not_cached"
MYSQL_QCACHE_NOT_CACHED=$VALUE
get_status_value "Qcache_inserts"
MYSQL_QCACHE_INSERTS=$VALUE
get_status_value "Qcache_hits"
MYSQL_QCACHE_HITS=$VALUE
if [ $MYSQL_QCACHE_HITS -gt 0 ]; then
    MYSQL_QUERY_CACHE_HITS=`echo "scale=4; ($MYSQL_QCACHE_HITS / ($MYSQL_QCACHE_HITS + $MYSQL_QCACHE_INSERTS + $MYSQL_QCACHE_NOT_CACHED)) * 100" | bc`
    MYSQL_QUERY_CACHE_HITS=`printf "%.02f" $MYSQL_QUERY_CACHE_HITS`
    $GMETRIC --name="${GMETRIC_NAME_HEADER}_query_cache_hits" --value="$MYSQL_QUERY_CACHE_HITS" --type="float" --units="%"
fi

MYSQL_THREADS_CACHE_HITS=`echo "scale=4; 100 - (($MYSQL_THREADS_CREATED / $MYSQL_CONNECTIONS) * 100)" | bc`
MYSQL_THREADS_CACHE_HITS=`printf "%.02f" $MYSQL_THREADS_CACHE_HITS`
$GMETRIC --name="${GMETRIC_NAME_HEADER}_threads_cache_hits" --value="$MYSQL_THREADS_CACHE_HITS" --type="float" --units="%"

get_status_value "Uptime"
MYSQL_UPTIME=$VALUE
MYSQL_QUERY_PER_SEC=`echo "scale=4; $MYSQL_QUESTIONS / $MYSQL_UPTIME" | bc`
MYSQL_QUERY_PER_SEC=`printf "%.02f" $MYSQL_QUERY_PER_SEC`
$GMETRIC --name="${GMETRIC_NAME_HEADER}_query_per_sec" --value="$MYSQL_QUERY_PER_SEC" --type="float" --units="Queries"


MYSQL_SLAVE_STATUS=`mysql -u root -S $SOCKET -e 'show slave status \G'`
if [ -n "$MYSQL_SLAVE_STATUS" ]; then
    OLD_IFS=$IFS
    IFS='
'

    for i in $MYSQL_SLAVE_STATUS; do
        IFS=' '
        MYSQL_SLAVE_STATUS_NAME=`echo $i | cut -d ':' -f 1`
        case $MYSQL_SLAVE_STATUS_NAME in
            'Seconds_Behind_Master')
                MYSQL_SECONDS_BEHIND_MASTER=`echo $i | cut -d ' ' -f 2`
                ;;
            'Master_Log_File')
                MYSQL_MASTER_LOG_FILE=`echo $i | cut -d ' ' -f 2`
                MYSQL_MASTER_LOG_FILE=`echo $MYSQL_MASTER_LOG_FILE | cut -d '.' -f 2`
                ;;
            'Relay_Master_Log_File')
                MYSQL_RELAY_MASTER_LOG_FILE=`echo $i | cut -d ' ' -f 2`
                MYSQL_RELAY_MASTER_LOG_FILE=`echo $MYSQL_RELAY_MASTER_LOG_FILE | cut -d '.' -f 2`
                ;;
            'Read_Master_Log_Pos')
                MYSQL_READ_MASTER_LOG_POS=`echo $i | cut -d ' ' -f 2`
                ;;
            'Exec_Master_Log_Pos')
                MYSQL_EXEC_MASTER_LOG_POS=`echo $i | cut -d ' ' -f 2`
                ;;
            esac
    done

    if [ $MYSQL_MASTER_LOG_FILE = $MYSQL_RELAY_MASTER_LOG_FILE ]; then
        MYSQL_SLAVE_LAG=`expr $MYSQL_READ_MASTER_LOG_POS - $MYSQL_EXEC_MASTER_LOG_POS`
    else
        max_binlog_size=1073741824
        part1=`expr $max_binlog_size - $MYSQL_EXEC_MASTER_LOG_POS`
        part2=`expr $MYSQL_MASTER_LOG_FILE - $MYSQL_RELAY_MASTER_LOG_FILE`
        if [ $part2 -gt 0 ]; then
            part2=`expr $part2 - 1`
        fi
        part2=`expr $part2 \* $max_binlog_size`
        MYSQL_SLAVE_LAG=`expr $part1 + $part2`
        MYSQL_SLAVE_LAG=`expr $MYSQL_SLAVE_LAG + $MYSQL_READ_MASTER_LOG_POS`
    fi

    $GMETRIC --name="${GMETRIC_NAME_HEADER}_slave_secs" --value="$MYSQL_SECONDS_BEHIND_MASTER" --type="uint16" --units="Seconds"
    $GMETRIC --name="${GMETRIC_NAME_HEADER}_slave_lag" --value="$MYSQL_SLAVE_LAG" --type="uint32" --units="Bytes"

    IFS=$OLD_IFS
fi


rm -f $MY_LOCK
