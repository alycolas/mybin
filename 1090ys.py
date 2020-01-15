#!/usr/bin/python2
# -*- coding: utf-8 -*-

# Module: default
# Author: Roman V. M.
# Created on: 28.11.2014
# License: GPL v.3 https://www.gnu.org/copyleft/gpl.html

import re
import time
import requests
from bs4 import BeautifulSoup
#import base64
#import urllib2
#import json
import sys
#import HTMLParser
#import re
#from urlparse import urlparse




def play(url):
    uheaders = {}
    uheaders['referer'] = url
    uheaders['user-agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.1 Safari/605.1.15"
    ucookies = {}
    ucookies['__cfduid']= 'd7775a564e6be4cf770deb7165835eb1e1577592176'
    ucookies['Hm_lpvt_e2526426c8588c6ac00d82d501ff28d8'] = str(int(time.time()))
    ucookies['Hm_lvt_e2526426c8588c6ac00d82d501ff28d8'] = '1577499144,1577525770,1577587676,1577589524'
    s = requests.session()
    r = s.get(url,verify=False, headers=uheaders)
    soup = BeautifulSoup(r.text)
    videourl = soup.find('div', class_='stui-player__video').find('iframe')['src']
    #print(s.cookies.get_dict())  # 先打印一下，此时一般应该是空的。
    r = s.get(videourl, verify=False, headers=uheaders, cookies=ucookies)
    vpattern = re.compile("video src\=\"([^\"]*)\"")
    vplayurl = vpattern.findall(r.text)[0].strip()
    # print(vplayurl)  # 先打印一下，此时一般应该是空的。
    return vplayurl


if __name__ == '__main__':
#    play("https://1090ys.com/play/3726~0~0.html")
    print(play(sys.argv[1]))
