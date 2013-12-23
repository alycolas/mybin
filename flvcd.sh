#!/bin/sh
#play internet video , power by www.flvcd.sh 
#Synatx
#	flvcd.sh [OPTION] [URL]

PLAYER='mplayer'
WGET='wget -T3'
title=`date +%j%H%M`

while getopts :hndwFf:p opt
do 
	case $opt in
		h) QULITY='high'
		   ;;
		n) QULITY='normal'
		   ;;
		d) PLAYER='aria2c -x3 -c -o'
		   ;;
		w) PLAYER='wget -c --user-agent=Mozilla/5.0\ \(Windows\;\ U\;\ Windows\ NT\ 5.1\;\ en-US\;\ rv:1.8.0.6\)\ Gecko/20060728\ Firefox/1.5 -O'
		#w) PLAYER='wget -c --user-agent=Opera/9.80\ \(X11\;\ Linux\ i686\)\ Presto/2.12.388\ Version/12.15 -O'
		   ;;
		f) EP=$OPTARG
		   # EP=`echo $PAR | cut -c3-`
		   ;;
		p) WGET='wget -e http_proxy=http://127.0.0.1:8087'
			;;
		F) PLAYER='mplayer -fs'
			;;
		'?') echo "$0: invalid option -$OPTARG" >&2
			 echo "Usage: $0 [-f NAME] [-hndwp] [1]" >&2
			 exit 1
	esac
done


if echo $* | grep -q \\-d || echo $* | grep -q \\-w 
then
	if echo $* | grep -q \\-f
	then
		shift $(($OPTIND - 1))
		echo  sdjfsfd $1
		$WGET "http://www.flvcd.com/parse.php?kw=$1&format=${QULITY:-super2}" -O - | #2>/tmp/log$$ |
			grep "onclick" |
			cut -d "\"" -f2 |
			sed 's/^/\"/;s/$/\"/g' |
			nl -nrz -w2 | 
		  while read url
		  do
			echo $PLAYER ${EP}_$url | sh - #${title}_$url | sh -
		  done
			  # sed "s/^/$PLAYER ${EP}${title}_/" |
			  # sh - # >>/tmp/log$$ >/dev/pts/0 2>&1 
			
		if ls ${EP}_[0-9][0-9] | grep -q _02 
		then
			if file ${EP}_[0-9][0-9] | grep -q MPEG
			then
				if python2.7 ~/lixian/mp4_join.py --output ${EP}.mp4 ./${EP}_[0-9][0-9]
				then
					rm ${EP}_[0-9][0-9]
				fi
			else
				if python2.7 ~/lixian/flv_join.py --output ${EP}.flv ./${EP}_[0-9][0-9]
				then
					rm ${EP}_[0-9][0-9]
				fi
			fi
		else
			if file ${EP}_[0-9][0-9] | grep -q MPEG
			then
				mv ${EP}_01 ${EP}.mp4
			else
				mv ${EP}_01 ${EP}.flv
			fi
		fi
	else
		echo ====================================================== >&2
		echo PLEASE ENTER THE FILE NAME ! >&2
		echo FOR EXEMPLAR: 	flvcd.sh -d -f \[NAME\] \[URL\] >&2
		echo ====================================================== >&2
		exit 1
	fi
	
else
	shift $(($OPTIND - 1))
	$WGET "http://www.flvcd.com/parse.php?kw=$1&format=${QULITY:-super2}" -O -| # 2>/tmp/log$$ |
	grep "onclick" |
	cut -d "\"" -f2 | while read url
	do
	wget -T2 --user-agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.6) Gecko/20060728 Firefox/1.5" -O- $url 2>/dev/pts/0 |
	$PLAYER - | 
	grep Quit && exit 2
done
fi
