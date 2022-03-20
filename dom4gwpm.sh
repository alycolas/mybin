#!/bin/sh

URL="https://www.domp4.cc/html/HnewwJDDDDDJ.html"
DIR=/home/tiny/dm/国王排名

if [ ! -f $DIR/old ]; then
    mkdir $DIR
    touch $DIR/old
fi

cd $DIR

curl $URL | sed -e 's/|/\n/g' | grep '[a-z0-9]\{40\}' | sed -e "s/'.*//" | sort > new

sleep 2

diff old new | grep '>' | sed -e 's/> /magnet:?xt=urn:btih:/' | \
while read MAG
do
    transmission-remote -n tiny:200612031 -w $DIR -a "$MAG"
done

cat new > old
