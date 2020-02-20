#!/bin/sh

echo "find $1/$2/* -exec aria2c -c -d $3/$2 https://proud-pine-e240.alycolas.workers.dev/{} \;"

mkdir -p $3/$2
$ read
cd /home/tiny/gdrive
find $1/$2/* -exec aria2c -c -d $3/$2 https://proud-pine-e240.alycolas.workers.dev/{} \;
