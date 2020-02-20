#!/bin/sh

mkdir -p $3

cd /home/tiny/team
# find $1/$2/* -exec aria2c -c -d $3/$2 https://damp-bar-411d.alycolas.workers.dev/{} \;

ls "$1""$2" | while read i
do
	aria2c -c -d $3 "https://damp-bar-411d.alycolas.workers.dev/$i"
done
