#!/bin/sh

S=${4:-"1"}
for i in `seq -w $2 $3`;
do
	aria2c -o $5S${S}E$i.mp4 `1090ys.py https://1090ys.com/play/$1~0~$[$i-1].html`;
done

