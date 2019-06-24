#!/bin/sh

wget "http://cili03.com/?topic_title3=$1" -O - 2>null | grep magnet= -A4 | sed -e 's;"m;>m;' -e 's;" ;>;' -e 's;</.>;>;' -e 's;^.*</dt>;>;' | cut -d\> -f3 |less

