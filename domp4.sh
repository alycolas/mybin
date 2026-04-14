#!/bin/sh

URL="https://m.domp4.cc/html/$1.html"
DIR=/home/tiny/$2

if [ ! -f $DIR/old ]; then
    mkdir $DIR
    touch $DIR/old
fi


curl $URL | sed -e "s/[\|\']/\n/g" | grep '[a-z0-9]\{40\}' | sort > $DIR/new

sleep 2

if [ ! $3 ]
then
diff $DIR/old $DIR/new | grep '>' | sed -e 's/> /magnet:?xt=urn:btih:/' | \
while read MAG
do
    transmission-remote -n tiny:200612031 -w $DIR -a "$MAG"
done
fi

cat $DIR/new > $DIR/old
