#!/bin/sh

MAG=`curl https://thepiratebay.org/search/"$1"/0/3/208 | grep magnet: | grep 1080p | cut -d \" -f 2 | sed -n 1p`

transmission-remote -n tiny:200612031 -w /home/tiny/hd/tv/"$1" -a "$MAG"
