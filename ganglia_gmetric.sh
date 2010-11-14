#!/bin/sh

NAME=gmetric_start
INTERVAL=60
GMETRIC_DIR=<%= gmetric_dir %>

exec_gmetric()
{
    for i in `ls -rt $GMETRIC_DIR/*.sh`; do
        if [ $i != $0 ]; then
            $i $1 | logger -p "local0.notice"
        fi
    done
}

if [ "x$1" == "x--clean" ]; then
    exec_gmetric $1
    exit 0
fi

case "$1" in
    [1-9][0-9]|[1-9][0-9][0-9])
        INTERVAL=$1
        ;;
esac

while true; do
    exec_gmetric
    sleep $INTERVAL
done

