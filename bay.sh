#!/bin/sh

wget -O /tmp/bay  https://thepiratebay.org/search/"$1"/0/7/200
#wget -O /tmp/bay  https://www.thepiratebay.org/search/"$1"/0/7/200
# curl -s  https://thepiratebay.org/search/"$1"/0/7/200 > /tmp/bay

DIR=hd

case "$2" in
	tv)
		DIR="hd/tv"
		;;
	mov)
		DIR="hd/movie"
		;;
	btv)
		DIR="backup/tv"
		;;
	bmov)
		DIR="backup/movies"
		;;
esac

#WC=${3:-"1"}
WC=1

grep -A4 Details /tmp/bay | sed -e 's/B,.*/B/' -e 's/^.*">//' | sed -e 's/\&nbsp\;/ /g' -e '/^</d' -e '/td>/d' | head -n17

read WC

MAG=`grep magnet: /tmp/bay | cut -d \" -f 2 | sed -n ${WC}p`

DIR="$DIR/$3"

transmission-remote -n tiny:200612031 -w /home/tiny/$DIR -a "$MAG"
