#!/bin/sh

DIR=hd

case "$3" in
	tv)
		DIR="hd/tv"
		;;
	mov)
		DIR="hd/movie"
		;;
	btv)
		DIR="backup/tv"
		;;
	bmov)
		DIR="backup/movies"
		;;
	dm)
		DIR="dm"
		;;
esac

DIR="$DIR/$4"

S=${5:-"1"}

NEW=`curl http://1090ys.com/show/$1.html | grep "$1~0" | sed -n '$p' | sed -e 's/.*0~\(.*\)\.html.*/\1/'`

echo $NEW
for i in `seq -w $[$NEW-$2] $NEW`;
do
	aria2c -o $4.S${S}E$[$i+1].mp4 -d /home/tiny/$DIR `/home/tiny/bin/1090ys.py http://1090ys.com/play/$1~0~$i.html 2>/dev/null`;
done

curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=$4$[$i+1]" -d "&desp=名字：$4$[$i+1] %0D%0A%0D%0A目录：$DIR"
