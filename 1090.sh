#!/bin/sh

wget -O /tmp/1090 "http://1090ys.com/?c=search&wd=$1&sort=addtime&order=des"

grep lazyload /tmp/1090 | cut -d\" -f4,6 | nl

read WC

if [ ! $WC ]
then
	exit
fi

NUM=`grep lazyload /tmp/1090 | cut -d\" -f4 | sed -e "s/[^0-9]//g"| sed -n ${WC}p`
NAM=`grep lazyload /tmp/1090 | cut -d\" -f6 | sed -n ${WC}p`

DIR=hd

movie(){
	curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=下载$NAM$NUM" -d "&desp=名字：$NAM %0D%0A%0D%0A目录：$DIR" 1>/dev/null
	aria2c -o ${NAM}.mp4 -d /home/tiny/$DIR `1090ys.py "https://1090ys.com/play/$NUM~0~0.html" 2>/dev/null`;
}

tvshow(){
	S=${3:-"1"}

	END=`curl http://1090ys.com/show/$NUM.html | grep "$NUM~0" | sed -n '$p' | sed -e 's/.*0~\(.*\)\.html.*/\1/'`
	echo 共$[$END+1]集，请选择下载集数，格式：01 $[$END+1]。

	read BIG END

	if [ ! $BIG ]
	then
		exit
	fi

	curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=下载$NAM$NUM共计第$BIG至$END集" -d "&desp=名字：$NAM$NUM %0D%0A%0D%0A目录：$DIR" 1>/dev/null

	for i in `seq -w $BIG $END`;
	do
		echo 开始下载第$i集
		aria2c -o S${S}E$i.mp4 -d /home/tiny/$DIR `1090ys.py "https://1090ys.com/play/$NUM~0~$[$i-1].html" 2>/dev/null`
		echo $i
	done
}

case "$2" in
	tv) DIR="hd/tv/$1"
		tvshow
		;;
	mov) DIR="hd/movie/$NAM"
		movie
		;;
	btv) DIR="backup/tv/$1"
		tvshow
		;;
	bmov) DIR="backup/movies/$NAM"
		movie
		;;
	dm) DIR="dm/$1"
		tvshow
		;;
	*)  echo '请输入正确的下载目录（tv,btv,bmov,mov,dm)'
		exit
		;;
esac

curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=$NAM$NUM下载完成" -d "&desp=名字：$NAM$NUM %0D%0A%0D%0A目录：$DIR" 1>/dev/null
