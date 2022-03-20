#!/bin/sh

cd /home/tiny/wd/tv/棋魂.2020/
MAG=`curl https://www.bt-tt.com/html/guochanju/8332.html |  grep magnet | tail -n1 | cut -d \" -f 8`

if grep $MAG mag
then
    exit
else
    transmission-remote -n tiny:200612031 -w /home/tiny/wd/tv/棋魂.2020/ -a "$MAG"
    echo $MAG > mag
fi
