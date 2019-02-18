#bin/bash

#
# Help
#

function help {
	echo "Capture and show stream based on UVC camera. Optionally add scoreboard and playback"
	echo "Call $(basename $0) -v 1|2|3... -s hd480|hd720|hd1080|WxH -r 10|24|25|30... -a 0|1|0:0... -b -h -V -R"
	echo "Ie. \`es2_capture.sh -v 2 -s hd720 -r 24 -a 2\`"
	echo "-v video input device number. Use es_devices.sh"
	echo "-s video size. Use es_devices.sh"
	echo "-r video rate. Use es_devices.sh"
	echo "-a audio input card and optionally subdevice. Use es_devices.sh"
	echo "-X show stream"
	echo "-V verbose"
	echo "-h help - this text"
	echo "-R ffmpeg report"
	echo "-N no output file. Default is ./stream/timestamped-file.mkv"
	echo "-S include scoreboard"
	exit 0
}

#
# Constants
#

VIDEOOUTPUTCODEC="-c:v mjpeg -q:v 1 -r 25"
AUDIOOUTPUTCODEC="-c:a aac -b:a 128k -ar 44100 -strict -2"
THREAD_QUEUE_SIZE="-thread_queue_size 32"
STDFILTER="setpts=PTS-STARTPTS,fps=25"

#
# Variables
#

# BROADCAST=""
# #FN=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
# FT=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
# #FC=red
# # Font and box
# FB="fontsize=30:fontcolor=red:box=1:boxcolor=black"

#
# Handle command line arguments. See http://wiki.bash-hackers.org/howto/getopts_tutorial
#

while getopts "v:s:r:a:n:VhRXNS" opt; do
case $opt in
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
	S)
	SCOREBOARD=Y
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
	N)
	NOOUTPUT=Y
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

if [ "$VDEVICE" == "" ]
then
	echo "Specify video input device number, option -v"
	help
fi

if [ "$SIZE" == "" ]
then
	echo "Specify video size, option -s"
	help
fi

if [ "$FPS" == "" ]
then
	echo "Specify video rate, option -r"
	help
fi

if [ "$ADEVICE" == "" ]
then
	echo "Specify audio input card and optionally subdevice, option -a"
	help
fi


#
#	Input
#

# Main camera, video input 0
VIDEO_IN="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -i /dev/video${VDEVICE}"

# Main audio
AUDIO_IN="-f alsa ${THREAD_QUEUE_SIZE} -i hw:${ADEVICE}"

# Overlays
if [ "$SCOREBOARD" == "Y" ] && [ "$PLAYBACK" == "Y" ]
then
	echo Scoreboard and playback
	OVERLAYS_IN="-re -loop 1 -i scoreboard.png"
	FILTERCOMPLEX_OVERLAYS=";[1:video]${STDFILTER}[scoreboard]"
elif [ "$SCOREBOARD" == "Y" ]
then
	echo Scoreboard
	OVERLAYS_IN="-re -loop 1 -i scoreboard.png"
	FILTERCOMPLEX_OVERLAYS=";[2:video]${STDFILTER}[scoreboard];[cam][scoreboard]overlay=main_w-overlay_w-10:main_h-overlay_h-10[videores]"
elif [ "$PLAYBACK" == "Y" ]
then
	echo Playback
	OVERLAYS_IN="-re -loop 1 -i scoreboard.png"
	FILTERCOMPLEX_OVERLAYS=";[1:video]${STDFILTER}[scoreboard]"
else
	FILTERCOMPLEX_OVERLAYS=";[cam]null[videores]"
fi

#
# Maps
#




#
# Filter complex
#

FILTERCOMPLEX="\
[0:video]${STDFILTER}[cam]\
;[1:audio]anull[audio]\
${FILTERCOMPLEX_OVERLAYS}\
;[videores]split[video][videox]"

#
# Output
#

VIDEO_OUT_OPTIONS="-map [video] ${VIDEOOUTPUTCODEC}"
AUDIO_OUT_OPTIONS="-map [audio] ${AUDIOOUTPUTCODEC}"
VIDEO_OUT_DISPLAY="-map [videox] -f xv -pix_fmt yuv420p display"

#
# Handle Ctrl-C.
#
int_handler()
{
	exit
}
trap 'int_handler' INT

#
# Make directory for output file
#
if [ ! -d stream ] && [ "$NOOUTPUT" == "" ]
then
	mkdir stream
fi

#
# Capture until ctrl+c
#

while true; do
	echo -en "\033]2;Stream to LAN (\"${TYPE}\") from ( \"${DEVICE}\"). Size ${W}x${H}. Destination ${OUTPUT}\007"

	# Create output file?
	if [ "$NOOUTPUT" == "Y" ]
	then
		OUTPUT_FILE="-y -f matroska /dev/null"
	else
		OUTPUT_FILE=./stream/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv
	fi

	ffmpeg \
	${REPORT} \
	${VIDEO_IN} \
	${AUDIO_IN} \
	${OVERLAYS_IN} \
	-filter_complex ${FILTERCOMPLEX} \
	${VIDEO_OUT_OPTIONS} \
	${AUDIO_OUT_OPTIONS} \
	${OUTPUT_FILE} \
	${VIDEO_OUT_DISPLAY}
	# ${OUTPUTMAP} \
	# ${VIDEOOUTPUTCODEC} \
	# ${AUDIOOUTPUTCODEC} \
	# ${OUTPUT} \
	# ${BROADCAST}

	# Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
