#!/bin/sh

#URL=`curl "https://rarbgprx.org/torrents.php?imdb=$1" | grep "$1" | sed -n "/1080p/p" | sed -n "/\/torrent\//p" | cut -d \" -f 28`
URL=`curl "https://rarbgprx.org/torrents.php?imdb=$1" | grep 'lista2"'| cut -d \" -f 28`


MAG=`curl "https://rarbgprx.org$URL" | sed -n /magnet:/p | cut -d\" -f24`

#echo $MAG
transmission-remote -n tiny:200612031 -w /home/tiny/hd/tv -a "$MAG"
