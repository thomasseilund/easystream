#bin/bash

# set -x

# Sæt manuel exposure for Logitech C920, så fps er konstant uanset lysstyrke!
# v4l2-ctl -d 2 --set-ctrl=exposure_auto=1

#
# Defaults
#

# Devices. Leave DEV_CAM1 and DEV_CAM2 blank for no secondary cameras
DEV_CAM0=4
DEV_CAM1=
DEV_CAM2=
DEV_MIC0=0

# ffmpeg log level
LOGLEVEL="-loglevel debug"
LOGLEVEL=

# Frame SIZE
SIZE=640x360
SIZE=hd720

# Filters on all video count_frames
FILTER_DRAWTEXT="drawtext=fontsize=30:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:text='%{n}':box=1:x=(w-tw)/2:y=h-(2*lh)"
#FILTER_DRAWTEXT=""
FILTER_SETPTS="setpts=PTS-STARTPTS"

# Ports, numbers etc for overlays
PLAYBACK_PORT=5552
PLAYBACK_SRV=127.0.0.1
PLAYBACK_OVERLAYNUM=9
PLAYBACK_FILLERFRAMES=9

# Misc constants
PIX_FMT=yuvj420p
SED_DELIMITER=","
THREAD_QUEUE_SIZE="-thread_queue_size 1024"
ES_WRITE_FRAMES_QUIET="-q"
FILTER_SCRIPT=filter.d/filter

# Set input for video - CAM0, CAM1 and CAM2
CAM0="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${SIZE} -r 30 -i /dev/video${DEV_CAM0}"
CAM1="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s ${SIZE} -r 15 -i /dev/video${DEV_CAM1}"
CAM2="-f v4l2 ${THREAD_QUEUE_SIZE} -input_format mjpeg -s 640x480 -r 15 -i /dev/video${DEV_CAM2}"

# Set input for audio - microphone MIC0
AUDIO="-f alsa ${THREAD_QUEUE_SIZE} -i hw:${DEV_MIC0}"

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
# Option sanity check
#

if [ "$FILTER_SCRIPT" == "" ]
then
	echo "Specify script to ffmpeg option -filter_complex_script, option -f"
	help
fi

if ! [ -f "$FILTER_SCRIPT" ]
then
	echo "File "$FILTER_SCRIPT" does not exist, option -f"
	help
fi

#
# Cameras in use
#

if [ "$DEV_CAM1" == "" ]
then
	CAM1="-f lavfi -i color=c=yellow:size=400x300"
fi

if [ "$DEV_CAM2" == "" ]
then
	CAM2="-f lavfi -i color=c=green:size=400x300"
fi

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
sed "s${SED_DELIMITER}DRAWTEXT${SED_DELIMITER}${FILTER_DRAWTEXT}${SED_DELIMITER}g" ${FILTER_SCRIPT} | \
sed "s${SED_DELIMITER}SETPTS${SED_DELIMITER}${FILTER_SETPTS}${SED_DELIMITER}g" \
> ${FILTER_SCRIPT_TEMP}
#cat ${FILTER_SCRIPT_TEMP}
#exit

#
# Create playback filler image
#

if [ ! -d ./playbackFiller ]
then
	mkdir ./playbackFiller
fi
ffmpeg -y -f lavfi -i color=c=red:size=$SIZE -frames:v 25 -pix_fmt $PIX_FMT -f mjpeg ./playbackFiller/25.mjpeg
ffmpeg -y -f lavfi -i color=c=red:size=$SIZE -frames:v  1 -pix_fmt $PIX_FMT -f mjpeg ./playbackFiller/1.mjpeg

#
# Call ffmpeg wiht piped input from playback program
#

es_write_frames -d ${PLAYBACK_FILLERFRAMES} -o ${PLAYBACK_OVERLAYNUM} -b tcp://${PLAYBACK_SRV}:${PLAYBACK_PORT} ${ES_WRITE_FRAMES_QUIET} | \
ffmpeg \
${REPORT} \
${LOGLEVEL} \
${CAM0} \
${AUDIO} \
-f mjpeg ${THREAD_QUEUE_SIZE} -r 25 -i pipe:0 \
${CAM1} \
${CAM2} \
-filter_complex_script ${FILTER_SCRIPT_TEMP} \
-map "[video]" -map "[cam0copy]" -map "[playbackcopy]" -map "[cam1copy]" -map "[cam2copy]" -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -map "[audio]" -c:a aac -b:a 128k -ar 44100 -strict -2 ${OUTPUT_FILE} \
-map "[videox]" -f xv -pix_fmt yuv420p HD_Pro_Webcam_C920

#
# Delete adjusted user supplied filter
#

rm ${FILTER_SCRIPT_TEMP}
