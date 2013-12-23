#!/bin/bash
#play internet video

PLAYER='mplayer -playlist -'
QULITY='super'
for PAR in $*
do 
	case $PAR in
		-s)
			QULITY='super2'
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
		http*)
			URL=$PAR
	esac
done
if [ "$PLAYER" == "aria2c" ]
then
	title=`date +%s`
	curl -g "http://www.flvcd.com/parse.php?kw=$URL&format=$QULITY" |
		grep "onclick" |
		cut -d "\"" -f2 |
		sed -e "s/^/\"/g" -e "s/$/\"/g" |
		nl -nrz -w2 |
		sed "s/^/aria2c -o ${title}_/" |
		sh - >>/tmp/log$$ >/dev/pts/0 2>&1 # &
	# sleep 15
	# for i in {1..10}; do
	# 	if [ -f "${title}_0$i" ] 
	# 	then 
	# 		mplayer "${title}_0$i" >/dev/null
	# 	else
	# 		echo $i
	# 		break 
	# 	fi
	# done >/dev/pts/0 2>&1
	#rm ${title}*
else
	 curl -g "http://www.flvcd.com/parse.php?kw=$URL&format=$QULITY"	| # 2>/tmp/log$$ |
	 grep "onclick" |
	 cut -d "\"" -f2 |
	 $PLAYER #>>/tmp/log$$ 2>&1

	# curl -g "http://www.flvcd.com/parse.php?kw=$URL&format=$QULITY" | 
	# grep "onclick" |
	# cut -d "\"" -f2 | 
	# while read i
	# do 
	# 	echo $i
	# 	curl $i  | mplayer - #>>/dev/null 2>&1
	# done
fi

