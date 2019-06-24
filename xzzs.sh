#!/bin/sh


RSS="https://nyaa.si/?page=rss&q=%E8%B4%A4%E8%80%85%E4%B9%8B%E5%AD%99&c=0_0&f=0"
KEY="贤者之孙"

# wget `curl "$RSS"  | grep -A1 "$KEY" | grep torrent | sed -e s/.link.// -e s/..link.// | sed -n '1p'`
transmission-remote -n tiny:200612031 -w /home/tiny/hd/tv -a `curl "$RSS"  | grep -A1 "$KEY" | grep torrent | sed -e s/.link.// -e s/..link.// | sed -n '1p'`
