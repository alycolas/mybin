#!/bin/sh

MAG=`curl https://thepiratebay.org/search/"$1"/0/99/207 | grep magnet: | grep 1080p | cut -d \" -f 2 | sed -n 1p`

transmission-remote -n tiny:200612031 -w /home/tiny/hd/movie -a "$MAG"
