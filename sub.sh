#/bin/sh

#getsub
# cd /home/tiny/hd/movie
# ls > new

# NEWMOV=`diff new old |  grep "< " | sed 's/< //g' | cut -d'[' -f1 | sed -e 's/^/\n\n\[/' -e 's/$/\]/'`

curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=`echo $TR_TORRENT_NAME | sed -e 's/[^A-Za-z0-9]/_/g'`" -d "&desp=名字：$TR_TORRENT_NAME %0D%0A%0D%0A目录：$TR_TORRENT_DIR"
# curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=NewMovie" -d "&desp=新增电影如下：$NEWMOV"
PWD="$TR_TORRENT_DIR/$TR_TORRENT_NAME"
# diff new old |  grep "< " | sed 's/< //g' | while read j 
# do
	getsub -b --plex "$PWD"
	#chmod -R 775 "$PWD"
#	ubliminal download -l en -l zh "$PWD"
# done

# cp new old
