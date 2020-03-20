#!/bin/sh

inotifywait -m /var/www/file/upload -e create | while read p a f; do
	if echo $f | grep -i \.docx$ ; then
		pandoc $p/$f -o $p/$f.html
	elif echo $f | grep -i \.jpg$ ; then
		echo $f | sed -e "s/^.*$/<img src=\"&\" style=\"margin:2\" width=100%\/>/" >> $p/pic.html
	fi
done

