#!/bin/sh

DP=$1
shift

while [ "x$1" != "x" ]
do
	transmission-remote 192.168.1.1 -n xcloud:200612031 -w $DP -a "$1"
	shift
done
