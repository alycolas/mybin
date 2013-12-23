#!/bin/sh
#Mplayer online

#function online { wget -T5 --user-agent=Mozilla/5.0\ \(Windows\;\ U\;\ Windows\ NT\ 5.1\;\ en-US\;\ rv:1.8.0.6\)\ Gecko/20060728\ Firefox/1.5 $1 -O - | mplayer - 2>/dev/null 1>&2}
function online { wget -T3 --user-agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.6) Gecko/20060728 Firefox/1.5" $1 -O - | mplayer - 2>/dev/null 1>&2}
