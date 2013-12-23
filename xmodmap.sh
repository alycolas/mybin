#/usr/bin/sh

xmodmap -e "clear lock"
xmodmap -e "keycode 66 = Escape"
xmodmap -e "keycode 9 = Caps_Lock"
xmodmap -e "add lock = Caps_Lock"
