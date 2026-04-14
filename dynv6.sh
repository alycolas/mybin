#!/bin/sh

export ALL_PROXY=http://127.0.0.1:1080

IP=`ip -6 addr list scope global $device | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1`
if [[ $IP = `cat /tmp/ipv6` ]]
then
    echo "not change"
else
    curl "https://api.dynu.com/nic/update?username=alycolas&password=200612031&hostname=alycolas.dynu.net&myipv6=$IP"
    #curl "https://api.dynu.com/nic/update?username=alycolas&password=200612031&hostname=alycolas.dynu.net&myip=10.1.1.3&myipv6=$IP"
    echo $IP > /tmp/ipv6
fi
