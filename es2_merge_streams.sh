#!/bin/bash -x

function help {
	echo "Read from end of disk files 1.ts, 2.ts and 3.ts and create final.ts"
	echo "1.ts is main camera. 2.ts is gameclock. 3.ts is overlay"
	echo "2.ts can be delayed relative to 1.ts by option -d"
	echo "Call $0 -d delay -r -h"
	echo "-r ffmpeg report -h help"
	exit 0
}

STREAM1=`ls stream1/*.mkv | tail -n 1`
STREAM2=`ls stream2/*.mkv | tail -n 1`
STREAM3=`ls stream3/*.mkv | tail -n 1`
STREAM3=""

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
DELAY=0
while getopts ":d:rh" opt; do
	case $opt in
		d)
		DELAY=$OPTARG
		;;
	r)
		REPORT="-report"
		;;
	h)
		echo "Call $0 -d 0|1.5|-2.3 -s hd480|hd720|hd1080 -r -h"
		exit 1
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		help
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		help
		exit 1
		;;
	esac
done

# We must have ${STREAM1}
DURATION1=`es_duration.sh 1`
INPUT1="-re -ss ${DURATION1}s -i ${STREAM1}"

if [ -e "${STREAM2}" ] && [ -e "${STREAM3}" ]
then
	# We have ${STREAM1}, ${STREAM2} and ${STREAM3}
	FILTER="-filter_complex \
	[2:0]setpts=PTS+${DELAY}/TB[scoreboard];\
	[3:0]chromakey=green:0.1:0.0[X11];\
	[1:0][scoreboard]overlay=eof_action=endall:y=main_h-overlay_h[gamewithclock];\
	[gamewithclock][X11]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2[video]"
	DURATION2=`es_duration.sh 2`
	DURATION3=`es_duration.sh 3`
	INPUT2="-re -ss ${DURATION2}s -i ${STREAM2}"
	INPUT3="-re -ss ${DURATION3}s -i ${STREAM3}"
elif [ -e "${STREAM2}" ]
then
	# We have ${STREAM1} and ${STREAM2}
	FILTER="-filter_complex overlay=y=H-h:eof_action=endall"
	DURATION2=`es_duration.sh 2`
	INPUT2="-re -ss ${DURATION2}s -i ${STREAM2}"
elif [ -e "${STREAM3}" ]
then
	# We have ${STREAM1} and ${STREAM3}
	FILTER="-filter_complex \
	[2:0]setpts=PTS+${DELAY}/TB[scoreboard];\
	[1:0][scoreboard]overlay=eof_action=endall:y=main_h-overlay_h[video]"
	DURATION3=`es_duration.sh 3`
	INPUT3="-re -ss ${DURATION3}s -i ${STREAM3}"
fi

# sleep 4.0

while true; do
	echo -en "\033]2;Merge streams. Delay = ${DELAY} Output to final.ts\007"
	
	# epoch for start of final.mkv
	date +%s>"./epoch"

	ffmpeg \
		${REPORT} \
		-y \
		${INPUT1} \
		${INPUT2} \
		${INPUT3} \
		${FILTER} \
		-c:v mjpeg \
		-q:v 1 \
		-c:a copy \
		final.mkv
	
	# Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2
	
	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
