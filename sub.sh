#/bin/sh

curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=`echo $TR_TORRENT_NAME | sed -e 's/[^A-Za-z0-9]/_/g'`" -d "&desp=名字：$TR_TORRENT_NAME %0D%0A%0D%0A目录：$TR_TORRENT_DIR"

PWD="$TR_TORRENT_DIR/$TR_TORRENT_NAME"

if [ `echo $TR_TORRENT_DIR | grep dm` ]
then
	S=1
	if [ `echo $TR_TORRENT_DIR | grep 英雄` ]; then S=4; fi
	if [ `echo $TR_TORRENT_DIR | grep 七大罪` ]; then S=3; fi
	find "$PWD" -type f -exec  perl-rename -v "s/([^0-9SsEe])([0-9]{2})([^0-9])/\1S${S}E\2\3/g" {} \;
fi
export ALL_PROXY=http://127.0.0.1:1080
getsub -b --plex "$PWD"
