#!/bin/sh

while true 
do
	inotifywait -e create /home/tiny/backup/photos/DCIM/Camera/
	sleep 3600
	rsync -avPh --delete /home/tiny/backup/photos /run/media/tiny/405B-9E92/
done

