#!/bin/sh

trap "exit 1" HUP INT PIPE QUIT TERM
trap "rm $$*" EXIT

n=1

for i in "$@"
do
	ffmpeg -i "$i" -c copy -bsf h264_mp4toannexb $$_$n.ts
	((n++))
done

ffmpeg -i "concat:`echo $(ls $$_*) | sed -e 's/ \+/|/g'`" -c copy "$1".mkv
