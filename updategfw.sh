#!/bin/sh

python2.7 /home/alycolas/proxy/gfwlist2dnsmasq/gfwlist2dnsmasq.py

scp -P232 dnsmasq_list.conf root@192.168.1.1:/etc/dnsmasq.d
