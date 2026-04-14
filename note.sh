#!/bin/bash
#

if [[ `head -n1 ~/Downloads/note.db | grep aria2c` ]]
then
    aria2c -d `head -n1 ~/Downloads/note.db | cut -d\  -f2` -i ~/Downloads/note.db
#    echo "aira2c -d `head -n1 ~/Downloads/note.db | cut -d\  -f2` -i ~/Downloads/note.db"
fi
