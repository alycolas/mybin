#!/bin/sh


#rss
cd /home/tiny/Downloads

curl https://yts.am/rss/0/1080p/all/7 | grep 'https://yts.am/torrent/download' | cut -d\" -f2  > btnew

#curl https://yts.ag/rss/0/1080p/all/7 | grep -A1 "$(date +"%d %b")" | grep '.torrent' |cut -d\" -f2 | xargs wget -O $(date +"%m%d%H%M").torrent

diff btnew btold |  grep "< " | sed 's/< //g' | while read i 
do
	wget -O $(date +"%m%d%H%M%S").torrent $i 
done

mv btnew btold
