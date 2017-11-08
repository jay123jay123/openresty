#!/bin/bash
# kill process  --- sh update.sh 1

source /etc/profile
Ary="activity appcenter aroundopenapi bonus cas circle cloudtchstat cloudteach cloudwork exam exercisesbank growing integration member notify openapi pay teacheval headlines"

function proDeamon() {
	NUM=`ps aux |grep  update2 |grep openresty |wc -l`
	if [ $NUM -ge 2 ];then
		exit
	fi
}

function kilDeamon(){
	ps aux |grep update2 |grep -v grep  |awk '{print $2}' |xargs kill -9
	for NAM in $Ary
	do
		rm -f /tmp/$NAM
	done
}

function alert(){
	a=0
	if [ -f "/tmp/$1" ];then
		a=`cat /tmp/$1`
		if [ $a -ge 3 ];then
			return 0 
		fi
	fi
	#echo "调用curl"
	curl -X POST -d 'touser=CloudMonitor&content='$1' upstream update failed on '$2 http://192.168.8.253/sendchat.php >/dev/null 2>&1
	echo `expr $a + 1` > /tmp/$1
}

function rmalert(){
	if [ -f "/tmp/$1" ];then
		rm -f /tmp/$1
		#echo "调用rm"
		curl -X POST -d 'touser=CloudMonitor&content='$1' upstream update successfully on '$2 http://192.168.8.253/sendchat.php >/dev/null 2>&1
	fi
}

function setRedis(){
	for NAM in $Ary
	do
	
		#echo $NAM
		#echo 'DEL '$NAM'_new' |xargs   redis-cli  -h 192.168.30.47
		echo 'DEL '$NAM'_new' |xargs   redis-cli  -h 127.0.0.1
		#curl -XGET http://192.168.8.155:8080/v2/apps/$NAM/test/tasks 2>/dev/null | jq .tasks[].ipAddresses[].ipAddress  |xargs   redis-cli  -h 192.168.30.47  SADD $NAM"_new"
		host=`curl  --connect-timeout 3 -m 3   -XGET http://localhost:8080/v2/apps/$NAM/calico/tasks 2>/dev/null | jq .tasks[].ipAddresses[].ipAddress`
		if [ $? != 0 ];then
			#报警
			#echo $NAM"获取失败"
			alert $NAM `hostname`
			continue
		fi
		if [ `echo $host |awk '{print length($0)}'` -lt 10 ];then
			#报警
			#echo "长度错误"
			alert $NAM `hostname`
			continue
		fi
		echo $host  |xargs   redis-cli  -h 127.0.0.1  SADD $NAM"_new"
		echo 'RENAME '$NAM'_new ' $NAM |xargs   redis-cli  -h 127.0.0.1
		rmalert $NAM `hostname`
	done
}

if [ -n "$1" ];then
	kilDeamon
	exit
fi

proDeamon

#alert a
#rmalert a

while true 
do
	setRedis
	sleep 5
done


#for (( i=0;i<9;i++ ))
#do
#	setRedis 
#	sleep 5
#done
