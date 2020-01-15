#!/bin/sh

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

MAG=`curl http://www.zimuxia.cn/portfolio/$1 | grep magnet | sed -n '$p' | cut -d\" -f6`

DIR="$DIR/$1"

transmission-remote -n tiny:200612031 -w /home/tiny/$DIR -a "$MAG"
