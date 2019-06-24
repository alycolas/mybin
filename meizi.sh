#!/bin/sh

#curl http://jandan.net/ooxx 2>/dev/null | grep \<p\>\<img | cut -d "\"" -f2 |  aria2c  -j30  -c -d /tmp/current -i - & 
#
#sleep 5  
#
#feh -R1 -FYZdD3 --cycle-once /tmp/current 
#feh -t -W1280 -E95 --index-info '' /tmp/current

let current=`curl http://jandan.net/pic 2>/dev/null| grep -o -m 1 "\[[[:digit:]]\{4\}\]" |  grep -o "[[:digit:]]\{4\}"`
	# current=$(($current-1))

for i in {1..100}
do
	echo $current
	mkdir /tmp/$current
	curl http://jandan.net/pic/page-$current 2>/dev/null | grep \<p\>\<img | cut -d "\"" -f2 |  aria2c -j50 -q -c -d /tmp/$current -i - & 
	sleep 5 
	feh  -R1 -FYdZD4 --cycle-once /tmp/$current  
	killall aria2c 2>/dev/null
	rm -r /tmp/$current
	#	echo "Press any key to view next page !"
	read -n 1 
	current=$(($current-1))
done
