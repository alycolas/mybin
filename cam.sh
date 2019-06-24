#!/bin/bash

DATE=$(date +"%Y-%m-%d_%H%M")

#fswebcam -r 640x480 --set brightness=80% --set contrast=55% /home/httpd/html/dav/cam/$DATE.jpg
fswebcam -r 640x480 /home/httpd/html/dav/cam/$DATE.jpg

HTML=$(echo "<img src=\"$DATE.jpg\"\/>")
#HTML=$(echo "<img src=\"$DATE.jpg\" style=\"margin:2\"\/>")

sed -i "1i$HTML" /home/httpd/html/dav/cam/index.html
