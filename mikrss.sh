#!/bin/sh

## nyaa
# RSS="https://nyaa.si/?page=rss&q=$1&c=0_0&f=0"
# #RSS="https://nyaa.si/?page=rss&q=%E5%92%AA%E6%A2%A6%E5%8A%A8%E6%BC%AB%E7%BB%84+%E4%B8%80%E6%8B%B3%E8%B6%85%E4%BA%BA&c=0_0&f=0"
# KEY="$1"
# # wget `curl "$RSS"  | grep -A1 "$KEY" | grep torrent | sed -e s/.link.// -e s/..link.// | sed -n '1p'`
# transmission-remote -n tiny:200612031 -w /home/tiny/hd/tv -a `curl "$RSS"  | grep -A1 "$KEY" | grep torrent | sed -e s/.link.// -e s/..link.// | sed -n '1p'`


## 甜蜜计划
curl "$1" | sed -e 's/x-bittorrent/\n/g' | grep torrent\" | cut -d\" -f5 | \
	while read MAG
	do
		transmission-remote -n tiny:200612031 -w /home/tiny/hd/tv -a "$MAG"
	done
