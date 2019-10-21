#!/bin/sh

curl -s "https://rarbgprx.org/torrents.php?search=$1&order=seeders&by=DESC" | grep lista2 /tmp/rar | sed -e 's/return/\n/g' -e 's/B</\n/g' | grep title | cut -d\" -f3,5,36 > /tmp/rar

DIR=$2
WC=${3:-"1"}

cut -d\" -f2,3  --output-delimiter="--------" | nl -nrn

read WC

MAG=`grep /tmp/rar | cut -d \" -f 1 | sed -n ${WC}p`
echo $MAG

transmission-remote -n tiny:200612031 -w /home/tiny/hd/$DIR/$1 -a "$MAG"
