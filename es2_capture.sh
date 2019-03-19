#bin/bash

#
# Help
#

function help {
	echo "Capture and show stream from UVC camera"
	echo "Optionally add scoreboard and playback"
	echo "Call $(basename $0) -v 1|2|3... -s hd480|hd720|hd1080|WxH -r 10|24|25|30... -a 0|1|0:0... -b -h -V -R"
	echo "Ie. \`es2_capture.sh -v 2 -s hd720 -r 24 -a 1\`"
	echo "-v video input device number. Use es_devices.sh"
	echo "-s video size. Use es_devices.sh"
	echo "-r video input rate. Use es_devices.sh. Output rate is 25 fps"
	echo "-a audio input card and optionally subdevice. Use es_devices.sh"
	echo "-V verbose"
	echo "-h help - this text"
	echo "-R ffmpeg report. See report for overlay numbers"
	echo "-D path where stream is saved as timestamped-file.mkv. Path must exist"
	echo "-S overlay scoreboard"
	echo "-P overlay playback"
	exit 0
}

#
# Constants
#

PIX_FMT=yuvj420p
VIDEOOUTPUTCODEC="-pix_fmt ${PIX_FMT} -c:v mjpeg -q:v 1"
AUDIOOUTPUTCODEC="-c:a aac -b:a 128k -ar 44100 -strict -2"
THREAD_QUEUE_SIZE="-thread_queue_size 64"
STDFILTER="setpts=PTS-STARTPTS,fps=25"
IP=`hostname  -I | cut -f1 -d' '`
SCOREBOARD_PORT=5551
PLAYBACK_PORT=5552
SCOREBOARD_FONT_FILE_AND_SIZE="fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30"

#
# Handle command line arguments. See http://wiki.bash-hackers.org/howto/getopts_tutorial
#

while getopts "v:s:r:a:n:VhRD:SP" opt; do
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
	P)
	PLAYBACK=Y
	;;
	V)
	set -x
	;;
	h)
	help
	;;
	R)
	#REPORT="-report -loglevel trace"
	REPORT="-report"
	;;
	D)
	# remove traling slash
	STREAM_PATH=`echo $OPTARG | sed 's:/*$::'`
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
	echo "Specify video input rate, option -r"
	help
fi

if [ "$ADEVICE" == "" ]
then
	echo "Specify audio input card and optionally subdevice, option -a"
	help
fi


#
# If playback then create filler image
#

if [ "$PLAYBACK" == "Y" ]
then
	if [ ! -d ./playbackFiller ]
	then
		mkdir ./playbackFiller
	fi
	# ffmpeg -y -f lavfi -i color=c=green:size=$SIZE -frames:v 1 -pix_fmt $PIX_FMT -f mjpeg ./playbackNo/1.mjpeg
	ffmpeg -y -f lavfi -i color=c=green:size=$SIZE -frames:v 25 -pix_fmt $PIX_FMT -f mjpeg ./playbackNo/25.mjpeg
fi

#
#	Input
#

# Main camera, video input 0
VIDEO_IN="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${SIZE} -r ${FPS} -i /dev/video${VDEVICE}"

# Main audio
AUDIO_IN="-f alsa ${THREAD_QUEUE_SIZE} -i hw:${ADEVICE}"

OVERLAY_IN_PLAYBACK="-f mjpeg ${THREAD_QUEUE_SIZE} -i pipe:0"
OVERLAY_IN_SCOREBOARD="-f mjpeg ${THREAD_QUEUE_SIZE} -i scoreboard100.mjpeg"
SCOREBOARD_FILTER_SHOW_NUMBERS="\
drawtext=${SCOREBOARD_FONT_FILE_AND_SIZE}:fontcolor=red:box=1:boxcolor=black:text=11:x=63:y=25+main_h-100\
,drawtext=${SCOREBOARD_FONT_FILE_AND_SIZE}:fontcolor=red:box=1:boxcolor=black:text=22:x=101:y=25+main_h-100\
,drawtext=${SCOREBOARD_FONT_FILE_AND_SIZE}:fontcolor=red:box=1:boxcolor=black:text=3:x=200/2-text_w/2:y=50+main_h-100\
,drawtext=${SCOREBOARD_FONT_FILE_AND_SIZE}:fontcolor=red:box=1:boxcolor=black:text=44:x=25:y=72+main_h-100\
,drawtext=${SCOREBOARD_FONT_FILE_AND_SIZE}:fontcolor=red:box=1:boxcolor=black:text=55:x=(200-text_w)/2:y=72+main_h-100\
,drawtext=${SCOREBOARD_FONT_FILE_AND_SIZE}:fontcolor=red:box=1:boxcolor=black:text=66:x=140:y=72+main_h-100\
,zmq=bind_address=tcp\\\://${IP}\\\:${SCOREBOARD_PORT}"

# Overlays
if [ "$SCOREBOARD" == "Y" ] && [ "$PLAYBACK" == "Y" ]
then
	echo Scoreboard and playback
	# Find this number from ffmpeg report
	PLAYBACK_OVERLAYNUM=15
	OVERLAYS_IN="${OVERLAY_IN_SCOREBOARD} ${OVERLAY_IN_PLAYBACK}"

#	;[2:video]${STDFILTER},loop=loop=-1:size=1:start=0,${SCOREBOARD_FILTER_SHOW_NUMBERS}[scoreboard]\

	FILTERCOMPLEX_OVERLAYS="\
;[2:0]${STDFILTER},${SCOREBOARD_FILTER_SHOW_NUMBERS}[scoreboard]\
;[3:0]${STDFILTER}[playback]\
;[cam][scoreboard]overlay=main_w-overlay_w-10:main_h-overlay_h-10[videores0]\
;[videores0][playback]overlay=9999:eval=frame,zmq=bind_address=tcp\\\://${IP}\\\:${PLAYBACK_PORT}[videores]"
elif [ "$SCOREBOARD" == "Y" ]
then
	echo Scoreboard
	OVERLAYS_IN=${OVERLAY_IN_SCOREBOARD}
	FILTERCOMPLEX_OVERLAYS="\
;[2:0]${STDFILTER},${SCOREBOARD_FILTER_SHOW_NUMBERS}[scoreboard]\
;[cam][scoreboard]overlay=main_w-overlay_w-10:main_h-overlay_h-10[videores]"
elif [ "$PLAYBACK" == "Y" ]
then
	echo Playback
	# Find this number from ffmpeg report
	PLAYBACK_OVERLAYNUM=5
	OVERLAYS_IN=${OVERLAY_IN_PLAYBACK}
	FILTERCOMPLEX_OVERLAYS="\
;[2:0]${STDFILTER}[playback]\
;[cam][playback]overlay=9999:eval=frame:eof_action=endall,zmq=bind_address=tcp\\\://${IP}\\\:${PLAYBACK_PORT}[videores]"
else
	FILTERCOMPLEX_OVERLAYS=";[cam]null[videores]"
fi

#
# Filter complex
#

FILTERCOMPLEX="\
[0:0]${STDFILTER}[cam]\
;[1:0]anull[audio]\
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
# Capture until ctrl+c
#

while true; do
	echo -en "\033]2;Stream to LAN (\"${TYPE}\") from ( \"${DEVICE}\"). Size ${W}x${H}. Destination ${OUTPUT}\007"

	# Create output file?
	if [ "$STREAM_PATH" == "" ]
	then
		OUTPUT_FILE="-y -f matroska /dev/null"
	else
		OUTPUT_FILE=${STREAM_PATH}/`date +"%Y.%m.%d-%H-%M-%S"`.mkv
	fi

	if [ "$PLAYBACK" == "Y" ]
	then
		es_write_frames -d 750 -o ${PLAYBACK_OVERLAYNUM} -b tcp://${IP}:${PLAYBACK_PORT} 2>/dev/null | \
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
	else
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
	fi

	# Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
