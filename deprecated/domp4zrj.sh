#!/bin/sh

URL="https://m.domp4.cc/html/pN8zCB77777B.html"
DIR=/home/tiny/hd/tv/爱拼会赢

if [ ! -f $DIR/old ]; then
    mkdir $DIR
    touch $DIR/old
fi


curl $URL | sed -e 's/|/\n/g' | grep '[a-z0-9]\{40\}' | sed -e "s/'.*//" | sort > $DIR/new

sleep 2

diff $DIR/old $DIR/new | grep '>' | sed -e 's/> /magnet:?xt=urn:btih:/' | \
while read MAG
do
    transmission-remote -n tiny:200612031 -w $DIR -a "$MAG"
done

cat $DIR/new > $DIR/old
