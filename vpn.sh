#!/bin/sh

pon VPS
sleep 5
route add -net 0.0.0.0  netmask 0.0.0.0 dev ppp0
