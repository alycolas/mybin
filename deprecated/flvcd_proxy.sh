#!/bin/bash #play internet video

PLAYER='mplayer -playlist -'
QULITY='super'

for PAR in $*
do 
	case $PAR in
		-s)
			QULITY='super'
			;;
		-h)
			QULITY='high'
			;;
		-n)
			QULITY='normal'
			;;
		-v)
			PLAYER='cvlc'
			;;
		-d)
			PLAYER='aria2c'
			;;
		-f*)
			EP=`echo $PAR | cut -c3-`
			;;
		http*)
			URL=$PAR
	esac
done

if [ "$PLAYER" == "aria2c" ]
then
	title=`date +%s`
	wget -e "http_proxy=http://127.0.0.1:8087" "http://www.flvcd.com/parse.php?kw=$URL&format=$QULITY" -O - | #2>/tmp/log$$ |
		grep "onclick" |
		cut -d "\"" -f2 |
		sed -e "s/^/\"/g" -e "s/$/\"/g" |
		nl -nrz -w2 |
		sed "s/^/aria2c -o ${EP}${title}_/" |
		sh - # >>/tmp/log$$ >/dev/pts/0 2>&1 
	#if echo $URL | grep -q youku
	#then
		if file ${EP}${title}* | grep -q MPEG
		then
			python2.7 ~/lixian/mp4_join.py ./${EP}${title}*
		else
			python2.7 ~/lixian/flv_join.py ./${EP}${title}*
		fi
	#fi
	#sleep 15
	#for i in {1..10}; do
	#	if [ -f "${title}_0$i" ] 
	#	then 
	#		mplayer "${title}_0$i" >/dev/null
	#	else
	#		echo $i
	#		break 
	#	fi
	#done >/dev/pts/0 2>&1
	#rm ${title}*
else
  wget  -e "http_proxy=http://127.0.0.1:8087" "http://www.flvcd.com/parse.php?kw=$URL&format=$QULITY" -O -| # 2>/tmp/log$$ |
  grep "onclick" |
  cut -d "\"" -f2 |
  $PLAYER 
fi
