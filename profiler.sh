##########################################################################
MemParams="time,total,used,free,shared,buffers,cached"
UflowParams="time,underflows,underflows_a,underflows_b,underflows_c"
##########################################################################
printSymbols()
{
	for count in {1..150}
	do
		printf 	$1
	done
	printf "\n"	
}
printTimestamp()
{
	time=$(date +'%H:%M:%S')
	date=$(date +'%d/%m/%Y')
	printSymbols +
	printf "TIMESTAMP\n"
	printf "Time: ""$time\n"
	printf "Date: ""$date\n"
	printSymbols +
}
printTitle()
{
	printSymbols =							>> monitor.log
	printf "OUTPUT OF $1 COMMAND\n"			>> monitor.log
	printSymbols =							>> monitor.log
}
processCommand()
{
	case "$1" in
	top)
		exe="top -b -n 1"
		$exe > temp
		sed -i '1,2d' temp
		sed -i -n '/KiB/q;p' temp
		sed -i "s/%Cpu.*:/$time,/g" temp
		sed -i 's/[[:space:]]\+//g' temp
		sed -i 's/[\x61-\x7a]//g' temp
		Cpu=0
		while [ -s temp ]
		do
			if [ ! -f Cpu$Cpu.csv ]
			then
				printf "time,$Cpu.us,$Cpu.sy,$Cpu.ni,$Cpu.id,$Cpu.wa,$Cpu.hi,$Cpu.si,$Cpu.st\n"		>> Cpu$Cpu.csv
			fi
			sed -n '1p' temp 				>> Cpu$Cpu.csv
			sed -i '1d' temp
			let Cpu++
		done
		;;
	free)
		exe="free -m"
		$exe > temp
		sed -i '2!d' temp
		sed -i "s/Mem:/$time/" temp
		sed -i 's/[[:space:]]\+/,/g' temp
		if [ ! -f MemMonitor.csv ]
		then
			printf "$MemParams\n" 			>> MemMonitor.csv
		fi
		cat temp 							>> MemMonitor.csv
		;;
	interrupts)
		exe="cat /proc/interrupts"
		$exe > temp
		sed -i '1d' temp
		sed -i 's/:usb/Usb/g' temp
		if [ ! -f Interrupts.csv ]
		then
			printf "time,"					>> Interrupts.csv
			read -a arr <<< $( sed -r 's/:.*//' temp)
			for elem in ${arr[@]}
			do
				printf "$elem,"				>> Interrupts.csv
			done
			printf "\n"						>> Interrupts.csv
		fi
		printf "$time,"						>> Interrupts.csv
		sed -i 's/.*://g' temp
		sed -i 's/[A-Z].*//g' temp
		while [ -s temp ]
		do
			sum=0
			read -a arr <<< $( sed -n '1p' temp)
			for num in ${arr[@]}
			do
				let "sum=$sum+$num"
			done
			sed -i '1d' temp
			printf "$sum,"					>> Interrupts.csv
		done
		printf "\n"							>> Interrupts.csv
		;;
	underflows)
		exe="cat /sys/kernel/debug/tegradc.0/stats"
		$exe	> temp
		sed -i 's/underflows.*://' temp
		sed -i 's/[[:space:]]\+//g' temp
		if [ ! -f Underflows.csv ]
		then
			printf "$UflowParams\n" 		>> Underflows.csv
		fi
		printf "$time,"						>> Underflows.csv
		sed ':a;N;$!ba;s/\n/,/g' temp		>> Underflows.csv
		;;
	memstats)
		exe="tegra_memstats -c "ahb avp camera cpu display0 display1 gr2d gr3d hda host1x mpe pcie ptc sata" -n 1"
		;;
	*)
		exe="$1"
		;;
	esac
	$exe									>> monitor.log
}
exitScript()
{
	rm -f temp
	zip $dir/output.zip *.csv *.log
	rm -f *.csv *.log *.xlsm
	printf "Exited\n"
	exit 0
}
################################# MAIN PROGRAM ####################################
exitstatus=1
trap "printf '\nExiting..\n'; exitstatus=0 " TERM INT

if [ "$#" = "0" ]
then
	cat helpfile
else
	interval=$1
	dir=$2
	shift 2
	while true
		do
		printTimestamp						>> monitor.log
		for com in "$@"
		do
			printTitle "$com"
			processCommand "$com"
		done
		if [ $exitstatus = 0 ]
		then
			exitScript
		fi
		sleep $interval
	done
fi

printTimestamp								>> sys.log
tail -f /var/log/syslog						>> sys.log
####################################################################################
