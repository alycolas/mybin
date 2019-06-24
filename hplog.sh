#/bin/sh

ssh root@192.168.1.254 "cat /tmp/syslog.log" > /home/tiny/new
cd /home/tiny/
diff old new | grep "> " | sed 's/> //g' >> old
