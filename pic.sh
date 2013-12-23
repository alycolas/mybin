#!/bin/sh

let current=`curl http://jandan.net/pic 2>/dev/null| grep -o -m 1 "\[[[:digit:]]\{4\}\]" |  grep -o "[[:digit:]]\{4\}"`

if [[ "$#" != 0 ]]
then
	i=${2:-0}
	while [[ $i -le $1 ]]
	do
		curl http://jandan.net/pic/page-$((current-i)) | grep \<p\>\<img | cut -d "\"" -f2 | sed -e "s/^.*$/<img src=\"&\" style=\"margin:2\"\/>/g"  >>/tmp/$$.html
		((i++))
	done
		opera /tmp/$$.html	
else
	for i in {1..100}
	do
		echo $current
		mkdir /tmp/$current
		curl http://jandan.net/pic/page-$current 2>/dev/null | grep \<p\>\<img | cut -d "\"" -f2 |  aria2c -j50 -q -c -d /tmp/$current -i - & 
		sleep 5 
		feh  -R1 -FYdZD4 --cycle-once /tmp/$current  
		killall aria2c 2>/dev/null
		rm -r /tmp/$current
		echo "Press any key to view next page !"
		read -n 1 
		current=$((current-1))
	done
fi
