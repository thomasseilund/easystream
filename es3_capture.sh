#bin/bash

# set -x

#
# Constants
#

PLAYBACK_PORT=5552
PLAYBACK_SRV=127.0.0.1
PLAYBACK_OVERLAYNUM=7
SIZE=hd720
PIX_FMT=yuvj420p
# FILTER_FOR_FRAMES. All video frames use this drawtext filter. Leave blank for no filter
FILTER_FOR_FRAMES=",drawtext=fontsize=30:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:text='%{n}':box=1:x=(w-tw)/2:y=h-(2*lh)"
FILTER_FOR_FRAMES=""
THREAD_QUEUE_SIZE="-thread_queue_size 1024"
# Set input for CAM0, CAM1 and CAM2. Feed CAM1 and CAM2 from lavfi these CAMS are not setup
CAM0="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${SIZE} -r 30 -itsoffset 1000 -i /dev/video0"
CAM1="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${SIZE} -r 15 -i /dev/video2"
CAM2="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s 640x480 -r 15 -i /dev/video4"
#CAM1="-f lavfi -i color=c=green:size=4x3"
#CAM2="-f lavfi -i color=c=red:size=4x3"
#CAM1="-f lavfi -i color=c=yellow:size=400x300"
#CAM2="-f lavfi -i color=c=green:size=400x300"

#
# Defaults
#

ES_WRITE_FRAMES_QUIET="-q"

function help {
	echo "Capture and show stream from UVC camera"
	echo "Optionally add scoreboard and playback"
	echo "Call $(basename $0) -f es_capture_filter_script"
	echo "Ie. \`es2_capture.sh -f es_capture_filter_script\`"
	echo "-f script to ffmpeg option -filter_complex_script"
	echo "-h help - this text"
	echo "-V verbose, bash script"
	echo "-R ffmpeg report. See report for overlay numbers"
	echo "-o debug overlay"
	echo "-D path where stream is saved as timestamped-file.mkv. Path must exist"
	exit 0
}

while getopts "f:hVRoD:" opt; do
case $opt in
	f)
		FILTER_SCRIPT=$OPTARG
		;;
	h)
		help
		;;
	V)
		set -x
		;;
	R)
		REPORT="-report"
		;;
	o)
		DEBUGOVERLAY=Y
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
# Debug overlay
#

if [ "$DEBUGOVERLAY" == "Y" ]
then
	LOGLEVEL="-loglevel quiet"
	ES_WRITE_FRAMES_QUIET=""
fi

#
# Create output file?
#

if [ "$STREAM_PATH" == "" ]
then
	OUTPUT_FILE="-y -f matroska /dev/null"
else
	[[ -d ${STREAM_PATH} ]] || mkdir ${STREAM_PATH}
	OUTPUT_FILE=${STREAM_PATH}/`date +"%Y.%m.%d-%H-%M-%S"`.mkv
fi

#
# Adjust user supplied filter
#

FILTER_SCRIPT_TEMP=`pwd`/${FILTER_SCRIPT}.$$
sed "sXFILTER_FOR_FRAMESX${FILTER_FOR_FRAMES}Xg" ${FILTER_SCRIPT} > ${FILTER_SCRIPT_TEMP}

#
# Create playback filler image
#

if [ ! -d ./playbackFiller ]
then
	mkdir ./playbackFiller
fi
ffmpeg -y -f lavfi -i color=c=red:size=$SIZE -frames:v 25 -pix_fmt $PIX_FMT -f mjpeg ./playbackFiller/25.mjpeg

#
# Call ffmpeg wiht piped input from playback program
#

es_write_frames -d 750 -o ${PLAYBACK_OVERLAYNUM} -b tcp://${PLAYBACK_SRV}:${PLAYBACK_PORT} ${ES_WRITE_FRAMES_QUIET} | \
ffmpeg \
${REPORT} \
${LOGLEVEL} \
${CAM0} \
-f alsa ${THREAD_QUEUE_SIZE} -i hw:1 \
-f mjpeg ${THREAD_QUEUE_SIZE} -i pipe:0 \
${CAM1} \
${CAM2} \
-filter_complex_script ${FILTER_SCRIPT_TEMP} \
-map "[video]" -map "[cam0copy]" -map "[playbackcopy]" -map "[cam1copy]" -map "[cam2copy]" -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -map "[audio]" -c:a aac -b:a 128k -ar 44100 -strict -2 ${OUTPUT_FILE} \
-map "[videox]" -f xv -pix_fmt yuv420p HD_Pro_Webcam_C920

#
# Delete adjusted user supplied filter
#

rm ${FILTER_SCRIPT_TEMP}
