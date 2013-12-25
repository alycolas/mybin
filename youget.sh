#!/bin/sh
#use you-get to play online vedio

[[ "$2" = "-p" ]] && export http_proxy="http://127.0.0.1:8087"

you-get -u $1 | 
grep "http" | 
sed -e "s/[][' )(]//g" -e "s/,/\n/g" | 
mplayer -fs -playlist -
