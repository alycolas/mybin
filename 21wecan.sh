#!/bin/sh

URL=`curl https://www.21wecan.com/sylm/rcpjxm/rcxw/ | grep date1 | sed -n 1p | cut -d\" -f2`
if [ "$URL" != "./202003/t20200331_8657.html" ]
then
    curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=21wecanNEWS" -d "&desp=https://www.21wecan.com/sylm/rcpjxm/rcxw/$URL"
else
    echo 未更新
fi
