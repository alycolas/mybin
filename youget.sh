#!/bin/sh
#use you-get to play online vedio

[[ "$2" = "-p" ]] && export http_proxy="http://127.0.0.1:8087"

you-get -u $1 | 
sed -n "/http/p" | 
sed -e "s/[][' )(]//g" -e "s/,/\n/g" | 
while read url
do 
	wget --referer="$1" --user-agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.6) Gecko/20060728 Firefox/1.5" $url -O - 2>/dev/pts/0 | 
	mplayer -fs - | 
	grep Quit && exit 2
done
