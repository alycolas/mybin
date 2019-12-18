#!/bin/sh

/home/tiny/.local/bin/rarbg >/dev/null 2>&1 &
sleep 5
wget -O /tmp/rarbg http://127.0.0.1:4444/search/$1
killall rarbg

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

#WC=${4:-"1"}
WC=1

#grep title /tmp/rarbg | cut -d\> -f2 | cut -d\< -f1 | sed 1d | nl

#read WC

MAG=`grep url /tmp/rarbg | cut -d \" -f 2 | sed -n ${WC}p`

DIR="$DIR/$3"

transmission-remote -n tiny:200612031 -w /home/tiny/$DIR -a "$MAG"
