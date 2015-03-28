#!/bin/sh

ssh -p 27774 root@104.224.168.29 youtube-dl "$1" $2>/tmp/filename

#scp -P 27774 root@104.224.168.29:/root/"$(grep Destination /tmp/filename | cut -d":" -f2 | sed -e "s/^ //" -e 's/ /\\ /g')" ./
