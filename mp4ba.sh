#!/bin/bash

html=$1

DIR="/home/tiny/hd/tv/清平乐/"

wget -O /tmp/html $html

EP=`grep "mp4ba.com<" /tmp/html | sed -e "s/.*\([0-9][0-9]\).*/\1/"`

MAG=`grep \"magnet /tmp/html | sed -n '$p' | cut -d\" -f2`


if grep -q $EP ${DIR}EP
then
    echo 无更新
else
    echo 下载开始
    echo  $MAG
    transmission-remote -n tiny:200612031 -w $DIR -a "$MAG"
    echo $EP >${DIR}EP
fi
