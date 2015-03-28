#!/bin/sh

you-get $1 >/tmp/$$ &
touch /tmp/$$1
sleep 30
while true
do
	grep 'Skipping' /tmp/$$ && break
	if [ "X$(cat /tmp/$$)" = "X$(cat /tmp/$$1)" ]
	then
		killall you-get
		you-get $1 >/tmp/$$ &
	fi
	cat /tmp/$$ > /tmp/$$1
	sleep 30
done
