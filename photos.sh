#!/bin/sh

for i in {2021..2022}
do
    for j in 0{1..9} 10 11 12
    do
        # mkdir -p /home/tiny/backup/photos/Sync/camera/$i/$j
        find *.jpg -name "*[^0-9]$i$j*" -exec mv {} /home/tiny/backup/photos/Sync/camera/$i/$j \;
    done
done
