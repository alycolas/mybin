#!/bin/bash

mkdir -p /home/tiny/alist_tv/$1

rclone lsd alist:/baidu/$1 | cut -d' ' -f22 | while read j
do
    mkdir -p "/home/tiny/alist_tv/$1/$j"
done

rclone ls alist:/baidu/$1 | sed -e "s/^[ 0-9]*[0-9]* //" | while read i
do
    echo /home/tiny/alist_tv/$1/$i.strm
    echo "https://alyk3.dynu.net/d/baidu/$1/$i"  > "/home/tiny/alist_tv/$1/$2$i.strm"
done
