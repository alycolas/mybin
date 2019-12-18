#!/bin/sh

base_url='https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt'

if [ -z "$TR_TORRENT_HASH" ] ; then
    echo 'This script should be called from transmission-daemon.'
    exit 1
fi

for tracker in $(wget -qO - ${base_url}) ; do
# logger -t $(basename $0) "Adding ${tracker} to $TR_TORRENT_NAME"
  transmission-remote -n tiny:200612031 -t $TR_TORRENT_HASH -td ${tracker}
done
