#!/bin/bash

if [ $1 ]
then
    echo "生成:$1.m3u"
    echo "#EXTM3U" > ~/m3u/"$1.m3u"
    ls ~/backup/photos/有声书/$1 | sed -e "s/.*/#EXTINF:-1,&\nhttp:\/\/htpc\/backup\/photos\/有声书\/$1\/&/" >> ~/m3u/"$1.m3u"
fi
