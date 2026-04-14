#!/bin/sh

#export http_proxy=http://127.0.0.1:1080
curl -s "http://23.234.231.104/search/$1?sort=seeders" > /tmp/rar
#curl -s "https://alyk3.dynu.net/search/$1?sort=seeders" > /tmp/rar
sleep 2

while grep "No results found" /tmp/rar
do
curl -s "https://alyk3.dynu.net/search/$1?sort=seeders" > /tmp/rar
sleep 2
done

DIR=$2
WC=${3:-"1"}

grep \( /tmp/rar | sed -e "s/<title>//" | sed -e "s/ *//"| nl -nrn
# cut -d\" -f2,3  --output-delimiter="--------" /tmp/rar | nl -nrn

read WC

for i in `echo $WC`
do
    MAG=`grep url= /tmp/rar | cut -d \" -f 2 | sed -n ${i}p`
    #MAG=`grep url= /tmp/rar | cut -d \" -f 2 | sed -n ${WC}p`
    echo $MAG
    transmission-remote -n tiny:200612031 -w /home/tiny/$DIR/"$1" -a "$MAG"
done
