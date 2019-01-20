#bin/bash

# Calls:
# Camera 1: (game camera)
# es2_capture.sh -t UVC -n 1 -v 1 -s hd720 -r 24 -a 1
# Scoreboard:
# es2_capture.sh -t scoreboard -n 2 -v 1

#
# Help
#

function help {
	echo "Capture stream based on UVC camera, scoreboard, X11 or test image"
	echo "Call $(basename $0) -t UVC|X11|scoreboard|test -v 0|1|2... -s hd480|hd720|hd1080|WxH -r 10|25|30... -a 0|1|0:0... -n 1|2|3... -b -h -V -R"
	echo "Ie. \`es2_capture.sh -t UVC -n 1 -v 2 -s hd720 -r 24 -a 1\`"
	echo "-t type of stream" 
	echo "-v video input device. Use v4l2-ctl --list-devices"
	echo "-s video size. Use v4l2-ctl --list-formats-ext -d 'video input device'" 
	echo "-r video rate. Use v4l2-ctl --list-formats-ext -d 'video input device'" 
	echo "-a audio input card and optionally subdevice. Use arecord -l"
	echo "-n stream number. Streams for this number are stored in seperate directory"
	echo "-b broadcast stream. See with ffplay -fflags nobuffer -i udp://236.0.0.1:200X for stream number X"
	echo "-V verbose"
	echo "-h help - this text"
	echo "-R ffmpeg report"
	exit 0
}

#
# Init variables
#
BROADCAST=""
#FN=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
FT=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
#FC=red
# Font and box
FB="fontsize=30:fontcolor=red:box=1:boxcolor=black"

#
# Handle command line arguments. See http://wiki.bash-hackers.org/howto/getopts_tutorial
#

while getopts "t:v:s:r:a:n:VhRb" opt; do
case $opt in
	t)
	TYPE=$OPTARG
	;;
	v)
	VDEVICE=$OPTARG
	;;
	s)
	SIZE=$OPTARG
	;;
	r)
	FPS=$OPTARG
	;;
	a)
	ADEVICE=$OPTARG
	;;
	n)
	STREAMNUMBER=$OPTARG
	;;
	b)
	BROADCAST=Y
	;;
	V)
	set -x
	;;
	h)
	help
	;;
	R)
      REPORT="-report"
	;;
	\?)
	echo "Invalid option: -$OPTARG" >&2
	help
	;;
	:)
	echo "Option -$OPTARG requires an argument." >&2
	help
	;;
esac
done

#
# Option sanity check
#

#if [ "$TYPE" == "" ]
if ! [[ "$TYPE" == "UVC" || "$TYPE" == "test" || "$TYPE" == "scoreboard" ]]
then
	echo "Missing or invalid stream type, option -t"
	help
fi

if [ "$VDEVICE" == "" ] && [ "$TYPE" == "UVC" ]
then
	echo "Specify video device, option -v"
	help
fi

if [ "$SIZE" == "" ] && ! [ "$TYPE" == "scoreboard" ]
then
	echo "Specify video size, option -s"
	help
fi

if [ "$FPS" == "" ] && [ "$TYPE" == "UVC" ]
then
	echo "Specify video rate, option -r"
	help
fi

if [ "$ADEVICE" == "" ] && [ "$TYPE" == "UVC" ]
then
	echo "Specify audio input card and optionally subdevice, option -a"
	help
fi

if [ "$STREAMNUMBER" == "" ]
then
	echo "Specify stream number, option -n"
	help
fi

# If output port is not an integer then assume it is a file name
if not [ "${STREAMNUMBER}" -eq "${STREAMNUMBER}" ] 2>/dev/null
then
	echo "Option -n, stream number, must be an integer"
	help
fi

if [ "$TYPE" == "scoreboard" ] && [ "$BROADCAST" == "Y" ]
then
	echo "Filter for scoreboard is not applied to broadcast."
	echo "Use:"
	echo "tail -f \`ls `pwd`/stream${STREAMNUMBER}/*.mkv | tail -n 1\` | ffplay -i pipe:0"
	echo "in seperate terminal windows once stream capturing is running"
	help
fi

#
# Find local ip for filter
# IP for host. Used by the zmq filters. Get first IP
#

IP=`hostname  -I | cut -f1 -d' '`

#
# Output to file
#

OUTPUT="./stream${STREAMNUMBER}/`date +"%Y.%m.%d-%H:%M:%S.%N"`-${STREAMNUMBER}.mkv"

#
# Output to broadcast/UDP
#

if [ "$BROADCAST" == "" ]
then
	BROADCAST=""
else
	BROADCAST="-f mpegts udp://236.0.0.1:200${STREAMNUMBER}"
fi

#
# Settings for most input types
#

VIDEOIN="[0:0]"
OUTPUTMAP="-map [video] -map [audio]"
#  "-qscale 1" needed for quality reasons - see https://lists.ffmpeg.org/pipermail/ffmpeg-user/2012-August/009095.html
VIDEOOUTPUTCODEC="-c:v mjpeg -q:v 1 -r 25"
AUDIOOUTPUTCODEC="-c:a aac -b:a 128k -ar 44100 -strict -2"
AUDIORECORDONOFFFILTER="azmq=bind_address=tcp\\\\\\://${IP}\\\\\\:5550,volume=volume=1:eval=frame"

#
# More settings depending on input type
#

if [ "$TYPE" == "UVC" ]
then
	AUDIOIN="[1:0]"
	VINPUT="-f v4l2 -thread_queue_size 32 -input_format mjpeg -s ${SIZE} -r ${FPS} -i /dev/video${VDEVICE}"
	AINPUT="-f alsa -thread_queue_size 32 -i hw:${ADEVICE}"
	FILTER="-filter_complex ${VIDEOIN}null[video];${AUDIOIN}${AUDIORECORDONOFFFILTER}[audio]"
elif [ "$TYPE" == "test" ]
then
	VINPUT="-re -f lavfi -i testsrc=size=$SIZE"
	AINPUT="-f lavfi -i sine=frequency=1000"
	FILTER="-filter_complex [0:0]null[video];[1:0]${AUDIORECORDONOFFFILTER}[audio]"
elif [ "$TYPE" == "scoreboard" ]
then
	AUDIOOUTPUTCODEC=""
	OUTPUTMAP="-map [video]"
	VINPUT="-re -loop 1 -i scoreboard.png"
	AINPUT=""
	FILTER="-filter_complex \
${VIDEOIN}\
drawtext=fontfile=$FT:${FB}:text=11:x=63:y=25+main_h-100,\
drawtext=fontfile=$FT:${FB}:text=22:x=101:y=25+main_h-100,\
drawtext=fontfile=$FT:${FB}:text=3:x=200/2-text_w/2:y=50+main_h-100,\
drawtext=fontfile=$FT:${FB}:text=44:x=25:y=72+main_h-100,\
drawtext=fontfile=$FT:${FB}:text=55:x=(200-text_w)/2:y=72+main_h-100,\
drawtext=fontfile=$FT:${FB}:text=66:x=140:y=72+main_h-100,\
zmq=bind_address=tcp\\\://${IP}\\\:5551\
[video]"

	# Also set the filter for broadcast. Otherwise filter is not applied to broadcast and we don't see updated scoreboard.
#	if ! [ "$BROADCAST" == "" ]
#	then
#		BROADCAST="-f mpegts ${FILTER} ${OUTPUTMAP} udp://236.0.0.1:200${STREAMNUMBER}"
#	else
#		BROADCAST=""
#	fi


	# FILTER=-"filter_complex ${VIDEOIN}drawtext=fontfile=$FT:text=XXXXXXX[video]"
	# FILTER=-"filter_complex ${VIDEOIN}null[video]"
fi

echo $FILTER

#
# Handle Ctrl-C.
#
int_handler()
{
	exit
}
trap 'int_handler' INT

#
# Make directory for stream
#
mkdir stream${STREAMNUMBER}

#
# Capture until ctrl+c
#

while true; do
	echo -en "\033]2;Stream to LAN (\"${TYPE}\") from ( \"${DEVICE}\"). Size ${W}x${H}. Destination ${OUTPUT}\007"

	# echo "1. ${REPORT}"
	# echo "2. ${VINPUT}"
	# echo "2. ${AINPUT}"
	# echo "3. ${FILTER}"
	# echo "4. ${OUTPUTMAP}"
	# echo "5. ${VIDEOOUTPUTCODEC}"
	# echo "6. ${AUDIOOUTPUTCODEC}"
	# echo "8. ${OUTPUT}"
	# exit

	#FILTER=""
	#OUTPUTMAP=""

	# epoch for start of capture
	date +%s>"./stream${STREAMNUMBER}/epoch"

	ffmpeg \
	${REPORT} \
	${VINPUT} \
	${AINPUT} \
	${FILTER} \
	${OUTPUTMAP} \
	${VIDEOOUTPUTCODEC} \
	${AUDIOOUTPUTCODEC} \
	${OUTPUT} \
	${BROADCAST}

	# Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
