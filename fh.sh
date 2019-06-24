#!/bin/sh

curl -s "https://sukebei.nyaa.si/?f=0&c=0_0&q=$1&s=seeders&o=desc" > /tmp/fh
DIR="hide"
WC=${3:-"1"}

grep -A7 \/view\/ /tmp/fh | cut -d\> -f2 | sed -e '/^$/d' -e '/^</d' -e 's/<.*$//' | head -n20

read WC

MAG=`grep magnet: /tmp/fh | cut -d \" -f 2 | sed -n ${WC}p`

transmission-remote -n tiny:200612031 -w /home/tiny/hide -a "$MAG"
