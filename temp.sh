#!/bin/bash 


for i in  {1..10000}
do 
	temp=`cat /sys/bus/pci/drivers/k8temp/0000:00:18.3/temp1_input|cut -c1,2`
	echo -ne " \033[40;32m[$temp]\033[0m"
	if [ $temp -le 45 ]; then
		for a in $(seq 40 $temp)
		do 
			echo -ne '\033[32m|||\033[0m'
		done
		echo -ne "\033[32m{$temp} \n\033[0m"
	elif [ $temp -lt 50 ]; then
		for a in $(seq 40 $temp)
		do 
			echo -ne '\033[33m|||\033[0m'
		done
		echo -ne "\033[33m{$temp} \n\033[0m"
	else 
		for a in $(seq 40 $temp)
		do 
			echo -ne '\033[31m|||\033[0m'
		done
		echo -ne "\033[31m{$temp} \n\033[0m"
	fi
	sleep 1
done
