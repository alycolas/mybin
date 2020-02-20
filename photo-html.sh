#!/bin/sh

ls *jpg | while read i
do
	r=`exiftool $i | grep Orientation | sed -e "s/[^[:digit:]]//g"`
	convert $i -rotate $r $i
	exiftool -Orientation=1 -n $i
done

ls *jpg | sed -e "s/^.*$/<img src=\"&\" style=\"margin:2\" width=100%\/>/" > index.html
