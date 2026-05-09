#!/bin/sh

if  curl https://manhua.fzdm.com/132/ | grep $1
then
    curl -s "https://sc.ftqq.com/SCU21184T2d614d48b5363a867d22c51324f8afc05a728a2da6f1a.send?text=一拳超人更新" -d "&desp=https://manhua.fzdm.com/132/"
else
    echo 未更新
fi
