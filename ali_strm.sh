#!/bin/bash

mkdir -p /home/tiny/alist_tv/$1

rclone lsd alist:/ali/$1 | cut -d' ' -f22 | while read j
do
    mkdir -p "/home/tiny/alist_tv/$1/$j"
done

#rclone ls alist:/ali/$1 | grep HD1080 | sed -e "s/^[ 0-9]*[0-9]* //" | while read i
rclone ls alist:/ali/$1 | sed -e "s/^[ 0-9]*[0-9]* //" | while read i
do
    echo /home/tiny/alist_tv/$1/$i.strm
    echo "https://alyk3.dynu.net/d/ali/$1/$i"  > "/home/tiny/alist_tv/$1/$2$i.strm"
done
