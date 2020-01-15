#!/bin/sh

sudo umount /mnt
sudo mount -o rw,username=tiny -U 405B-9E92 /mnt

rsync -auzh /home/tiny/backup/photo /mnt

sudo umount /mnt
