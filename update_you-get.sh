#/bin/sh

cd /tmp
wget https://aur.archlinux.org/cgit/aur.git/snapshot/you-get-git.tar.gz
tar xvf you-get-git.tar.gz
cd you-get-git
makepkg -sri
cd ~/
