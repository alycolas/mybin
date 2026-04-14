#!/bin/sh


ls mm*.jpg | while read NAM
do
    SEC=`echo $NAM | cut -b 9-18`
    SSEC=`echo $NAM | cut -b 19-21`
    NNAM=`date -d @$SEC +"%Y%-m%d-%H%M%S"`
    mv -i $NAM weixin-${NNAM}-$SSEC.jpg
done
