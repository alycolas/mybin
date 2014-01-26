#!/bin/sh

sed -i -E "s/(networks = \{').*('\})/\1$(dmesg | grep `lspci -v | grep -A12 Ethernet | sed  1,12d | cut -d':' -f2` | grep 'Link is up' | sed -E 's/.* (.*):.*/\1/')\2/" ~/.config/awesome/personal.lua
