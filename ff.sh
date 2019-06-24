#!/bin/sh

#$1是源文件，$2是码率，网络传输建议码率是1024k~2048k，$3是分辨率，720p是-1:720，-1表示根据高720保持比例缩放，$4是视频比例，看源视频了，比如4:3, 3:2, 16:9等，$5是输出文件名
ffmpeg -i $1 -vcodec libx264 -vprofile high -preset slow -b:v $2 -maxrate $2 -bufsize 4000k -vf scale=$3 -aspect $4 -threads 0 -pass 1  -acodec copy -f mp4 $5

#ffmpeg -i $1 -vcodec libx264 -vprofile high -preset slow -b:v $2 -maxrate $2 -bufsize 4000k -vf scale=$3 -aspect $4 -threads 0 -pass 2 -acodec libfaac -b:a $5 -f mp4 $6



