#!/bin/sh

## Motivation:
##    We have seen that nethermind can have some issues when this limit is low
## References:
##    https://www.suse.com/support/kb/doc/?id=000020048
##    https://aaujayasena.medium.com/how-to-increasing-the-amount-of-inotify-watchers-18f870fbdc40

MAX_USER_WATCHES=524288

current=$(cat /proc/sys/fs/inotify/max_user_watches)

if [ $current -lt $MAX_USER_WATCHES ];then
    cp /etc/sysctl.conf /etc/sysctl.conf.bck
    sysctl -w fs.inotify.max_user_watches=${MAX_USER_WATCHES}
    sed -i '/fs.inotify.max_user_watches=.*/d' /etc/sysctl.conf
    echo fs.inotify.max_user_watches=${MAX_USER_WATCHES} | tee -a /etc/sysctl.conf && sysctl -p || (cp /etc/sysctl.conf.bck /etc/sysctl.conf && sysctl -p)
else
    echo "The max_user_watches is correct"
fi
