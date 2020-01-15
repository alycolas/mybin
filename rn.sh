#!/bin/sh

S=${2:-"S1"}

find "$1" -regextype egrep -iregex '.*\.mp4|.*\.mkv' ! -iregex '.*[E][0-9]{1,3}[^0-9].*' -exec  perl-rename -nv "s/([^0-9])([0-9]{2})([^0-9])/\1${S}E\2\3/g" {} \;

read

find "$1" -regextype egrep -iregex '.*\.mp4|.*\.mkv' ! -iregex '.*[E][0-9]{1,3}[^0-9].*' -exec  perl-rename -v "s/([^0-9])([0-9]{2})([^0-9])/\1${S}E\2\3/g" {} \;
