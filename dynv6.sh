#!/bin/sh


IP=`curl https://ipv6.nsupdate.info/myip`
if [[ $IP = `cat /tmp/ipv6` ]]
then
    echo "not change"
else
    curl  http://dynv6.com/api/update\?hostname\=alycolas.dynv6.net\&token\=8o1jiLQzaauiyDX1swcy_uuPkVV3zU\&ipv6\=$IP
    echo $IP > /tmp/ipv6
fi
