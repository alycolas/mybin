#!/bin/sh

#curl -x "http://127.0.0.1:1080" -s "http://alyk3.dynu.net:4444/search/$1.1080p?sort=seeders" > /tmp/rar
curl -s "https://alyk3.dynu.net/search/$1.1080p?sort=seeders" > /tmp/rar
sleep 2

while grep "No results found" /tmp/rar
do
curl -s "https://alyk3.dynu.net/search/$1.1080p?sort=seeders" > /tmp/rar
sleep 2
done

MAG=`grep url= /tmp/rar | cut -d \" -f 2 | sed -n 1p`
echo $MAG
transmission-remote -n tiny:200612031 -w /home/tiny/$2/"$1" -a "$MAG"
