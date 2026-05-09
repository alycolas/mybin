#!/bin/sh

case "$2" in
	tv)
		DIR="hd/tv"
		;;
	mov)
		DIR="hd/movie"
		;;
	wtv)
		DIR="wd/tv"
		;;
	wmov)
		DIR="wd/movie"
		;;
	btv)
		DIR="backup/tv"
		;;
	bmov)
		DIR="backup/movies"
		;;
esac

# export http_proxy=http://127.0.0.1:1080
# export https_proxy=http://127.0.0.1:1080
## /home/tiny/.local/bin/rarbg >/dev/null 2>&1 &
## sleep 3
## wget -O /tmp/rarbg "http://127.0.0.1:4444/search/$1?sort=seeders"
## killall rarbg

/usr/local/bin/spider -k $1

# unset http_proxy
# unset https_proxy

# DIR=hd

# #WC=${4:-"1"}
# WC=1
#
# grep title /tmp/rarbg | cut -d\> -f2 | cut -d\< -f1 | sed 1d | nl
#
# read WC
#
# MAG=`grep url /tmp/rarbg | cut -d \" -f 2 | sed -n ${WC}p`
MAG=`cat /tmp/MAG`

DIR="$DIR/$3"

if [ ! -n "$2" ]; then
	six-cli rm movie -y
	sleep 3
	six-cli offline add $MAG -o /movie -y
	sleep 10
	if six-cli ls | grep movie; then
		cd /home/tiny/hd
		six-cli down movie/
	else
		echo "do you want to download with transmission, if then enter Download path"
		read DIR
		if [ -n "$DIR" ]; then
		transmission-remote -n tiny:200612031 -w /home/tiny/$DIR -a "$MAG"
		fi
	fi
else
	transmission-remote -n tiny:200612031 -w /home/tiny/$DIR -a "$MAG"
fi
