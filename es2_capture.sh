#bin/bash

# set -x

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
	echo "-V verbose, bash script"
	echo "-h help - this text"
	echo "-R ffmpeg report. See report for overlay numbers"
	echo "-D path where stream is saved as timestamped-file.mkv. Path must exist"
	echo "-S overlay scoreboard"
	echo "-P overlay playback"
	echo "-o debug overlay"
	echo "-1 v for extra live input number 1"
	echo "-2 s for extra live input number 1"
	echo "-3 r for extra live input number 1"
	echo "-4 v for extra live input number 2"
	echo "-5 s for extra live input number 2"
	echo "-6 r for extra live input number 2"
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
STDOVERLAY="overlay=9999:eval=frame:eof_action=endall"
IP=`hostname  -I | cut -f1 -d' '`
SCOREBOARD_PORT=5551
PLAYBACK_PORT=5552
EXTRACAM1_PORT=5553
EXTRACAM2_PORT=5554
SCOREBOARD_FONT_FILE_AND_SIZE="fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30"
ES_WRITE_FRAMES_QUIET="-q"

#
# Handle command line arguments. See http://wiki.bash-hackers.org/howto/getopts_tutorial
#

while getopts "v:s:r:a:n:VhRD:SPo1:2:3:4:5:6:" opt; do
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
	o)
	DEBUGOVERLAY=Y
	;;
	V)
	set -x
	;;
	1)
	V_EXTRACAM1=$OPTARG
	;;
	2)
	S_EXTRACAM1=$OPTARG
	;;
	3)
	R_EXTRACAM1=$OPTARG
	;;
	4)
	V_EXTRACAM2=$OPTARG
	;;
	5)
	S_EXTRACAM2=$OPTARG
	;;
	6)
	R_EXTRACAM2=$OPTARG
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
	# ffmpeg -y -f lavfi -i color=c=green:size=$SIZE -frames:v 1  -pix_fmt $PIX_FMT -f mjpeg ./playbackFiller/1.mjpeg
	ffmpeg -y -f lavfi -i color=c=green:size=$SIZE -frames:v 25 -pix_fmt $PIX_FMT -f mjpeg ./playbackFiller/25.mjpeg
fi

#
#	Input. Cam 0, main cam, and scoreboard and playback
#

# Main camera, video input 0 and audio input
AV_IN="\
-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${SIZE} -r ${FPS} -i /dev/video${VDEVICE} \
-f alsa ${THREAD_QUEUE_SIZE} -i hw:${ADEVICE}"

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
;[cam][scoreboard]overlay=main_w-overlay_w-10:main_h-overlay_h-10[videoresscoreboard]\
;[videoresscoreboard][playback]${STDOVERLAY},zmq=bind_address=tcp\\\://${IP}\\\:${PLAYBACK_PORT}[videores0]"

	# ffmppeg input stream number for extra cams:
	I_EXTRACAM1=4
	I_EXTRACAM2=5
elif [ "$SCOREBOARD" == "Y" ]
then
	echo Scoreboard
	OVERLAYS_IN=${OVERLAY_IN_SCOREBOARD}
	FILTERCOMPLEX_OVERLAYS="\
;[2:0]${STDFILTER},${SCOREBOARD_FILTER_SHOW_NUMBERS}[scoreboard]\
;[cam][scoreboard]overlay=main_w-overlay_w-10:main_h-overlay_h-10[videores0]"

	# ffmppeg input stream number for extra cams:
	I_EXTRACAM1=3
	I_EXTRACAM2=4
elif [ "$PLAYBACK" == "Y" ]
then
	echo Playback
	# Find this number from ffmpeg report
	PLAYBACK_OVERLAYNUM=5
	OVERLAYS_IN=${OVERLAY_IN_PLAYBACK}
	FILTERCOMPLEX_OVERLAYS="\
;[2:0]${STDFILTER}[playback]\
;[cam][playback]${STDOVERLAY},zmq=bind_address=tcp\\\://${IP}\\\:${PLAYBACK_PORT}[videores0]"

	# ffmppeg input stream number for extra cams:
	I_EXTRACAM1=3
	I_EXTRACAM2=4
else
	FILTERCOMPLEX_OVERLAYS=";[cam]null[videores0]"

	# ffmppeg input stream number for extra cams:
	I_EXTRACAM1=2
	I_EXTRACAM2=3
fi

#
#	Input. Extra cam 1 and 2
#

#ZMQ="zmq=bind_address=tcp"\\\\\\://${IP}\\\\\\$:"
#ZMQ="zmq"
echo $ZMQ
# exit

if ! [ "$V_EXTRACAM1" == "" ] && ! [ "$V_EXTRACAM2" == "" ]
then
	echo Extra cam1 and extra cam2

	AV_IN="${AV_IN} \
-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${S_EXTRACAM1} -r ${R_EXTRACAM1} -i /dev/video${V_EXTRACAM1} \
-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${S_EXTRACAM2} -r ${R_EXTRACAM2} -i /dev/video${V_EXTRACAM2}"

	FILTERCOMPLEX_OVERLAYS_EXTRACAM="\
;[${I_EXTRACAM1}:0]${STDFILTER},split[extracam1][extracam1copy]\
;[${I_EXTRACAM2}:0]${STDFILTER},split[extracam2][extracam2copy]\
;[videores0][extracam1]${STDOVERLAY},zmq=bind_address=tcp\\\://${IP}\\\:${EXTRACAM1_PORT}[videores1]\
;[videores1][extracam2]${STDOVERLAY},zmq=bind_address=tcp\\\://${IP}\\\:${EXTRACAM2_PORT}[videores]"

	EXTRACAM1COPY="-map [extracam1copy]"
	EXTRACAM2COPY="-map [extracam2copy]"

elif ! [ "$V_EXTRACAM1" == "" ]
then
	echo Extra cam1

	AV_IN="${AV_IN} \
-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${S_EXTRACAM1} -r ${R_EXTRACAM1} -i /dev/video${V_EXTRACAM1}"

	FILTERCOMPLEX_OVERLAYS_EXTRACAM="\
;[${I_EXTRACAM1}:0]${STDFILTER},split[extracam1][extracam1copy]\
;[videores0][extracam1]${STDOVERLAY},zmq=bind_address=tcp\\\://${IP}\\\:${EXTRACAM1_PORT}[videores]"

	EXTRACAM1COPY="-map [extracam1copy]"

elif ! [ "$V_EXTRACAM2" == "" ]
then
	echo Extra cam2

	AV_IN="${AV_IN} \
-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${S_EXTRACAM2} -r ${R_EXTRACAM2} -i /dev/video${V_EXTRACAM2}"

	FILTERCOMPLEX_OVERLAYS_EXTRACAM="\
;[${I_EXTRACAM2}:0]${STDFILTER},split[extracam2][extracam2copy]\
;[videores0][extracam2]${STDOVERLA},zmq=bind_address=tcp\\\://${IP}\\\:${EXTRACAM2_PORT}[videores]"

	EXTRACAM1COPY="-map [extracam2copy]"

else
	echo Only main cam

	FILTERCOMPLEX_OVERLAYS_EXTRACAM=";[videores0]null[videores]"

fi

#
# Filter complex
#

FILTERCOMPLEX="\
[0:0]${STDFILTER}[cam]\
;[1:0]anull[audio]\
${FILTERCOMPLEX_OVERLAYS}\
${FILTERCOMPLEX_OVERLAYS_EXTRACAM}\
;[videores]split[video][videox]"

#
# Output
#

VIDEO_OUT_OPTIONS="-map [video] ${EXTRACAM1COPY} ${EXTRACAM2COPY} ${VIDEOOUTPUTCODEC}"
AUDIO_OUT_OPTIONS="-map [audio] ${AUDIOOUTPUTCODEC}"
# Get name of input video and use as title for video on screen
VIDEO_OUT_DISPLAY_HEADER=`v4l2-ctl -d ${VDEVICE} -D | grep "Card type" | awk -F ": " '{print $2}'`
VIDEO_OUT_DISPLAY="-map [videox] -f xv -pix_fmt yuv420p ${VIDEO_OUT_DISPLAY_HEADER// /_}"

#
# Debug overlay
#

if [ "$DEBUGOVERLAY" == "Y" ] && [ "$PLAYBACK" == "Y" ]
then
	LOGLEVEL="-loglevel quiet"
	ES_WRITE_FRAMES_QUIET=""
fi


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
		[[ -d ${STREAM_PATH} ]] || mkdir ${STREAM_PATH}
		OUTPUT_FILE=${STREAM_PATH}/`date +"%Y.%m.%d-%H-%M-%S"`.mkv
	fi

	if [ "$PLAYBACK" == "Y" ]
	then

		echo ${OVERLAY_STDERR}
		echo ${OVERLAY_STDERR}
		echo ${OVERLAY_STDERR}
		echo ${OVERLAY_STDERR}
		echo ${OVERLAY_STDERR}

		# es_write_frames -d 750 -o ${PLAYBACK_OVERLAYNUM} -b tcp://${IP}:${PLAYBACK_PORT} 2>/dev/null | \
		es_write_frames -d 750 -o ${PLAYBACK_OVERLAYNUM} -b tcp://${IP}:${PLAYBACK_PORT} ${ES_WRITE_FRAMES_QUIET} | \
		ffmpeg \
		${LOGLEVEL} \
		${REPORT} \
		${AV_IN} \
		${OVERLAYS_IN} \
		-filter_complex ${FILTERCOMPLEX} \
		${VIDEO_OUT_OPTIONS} \
		${AUDIO_OUT_OPTIONS} \
		${OUTPUT_FILE} \
		${VIDEO_OUT_DISPLAY}
	else
		ffmpeg \
		${REPORT} \
		${AV_IN} \
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
