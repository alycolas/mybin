#!/bin/sh

curl -s  https://thepiratebay.org/search/"$1"/0/7/200 > /tmp/bay

DIR=$2
WC=${3:-"1"}

grep -A4 Details /tmp/bay | sed -e 's/B,.*/B/' -e 's/^.*">//' | sed -e 's/\&nbsp\;/ /g' -e '/^</d' -e '/td>/d' | head -n17

read WC

MAG=`grep magnet: /tmp/bay | cut -d \" -f 2 | sed -n ${WC}p`

transmission-remote -n tiny:200612031 -w /home/tiny/hd/$DIR -a "$MAG"
