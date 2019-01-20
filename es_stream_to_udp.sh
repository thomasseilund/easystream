#bin/bash
#
# OK      ffmpeg version N-79072-g83df0a8 Copyright (c) 2000-2016 the FFmpeg developers
# Not OK  ffmpeg version N-79389-g884dd17 Copyright (c) 2000-2016 the FFmpeg developers

function help {
  echo "Create a stream based on camera, scoreboard, X11 or test-image input and stream to UDP"
  echo "Call $0 -t hdpvr|logitech|X11|scoreboard|test -n 1|2|3 -d /dev/videoX -w factorOf16 -h factorOf16 -r -s +5.0 -h"
  echo "-t type of stream -n stream number -d camera input device -w stream width -h stream height -s sound delay (for type = logitech)"
  echo "-w and -h defaults are 852 and 480. For type = scoreboard defaults are 208 and 112"
  exit 0
}

# Defaults
AUDIODELAY=+0.0

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":t:n:d:s:w:h:hrx" opt; do
  case $opt in
		t)
      TYPE=$OPTARG
      ;;
		n)
      STREAMNUMBER=$OPTARG
      ;;
    d)
      DEVICE=$OPTARG
      ;;
    s)
      AUDIODELAY=$OPTARG
      ;;
    w)
      W=$OPTARG
      ;;
    h)
      H=$OPTARG
      ;;
    r)
      REPORT="-report"
      ;;
    x)
      set -x
      ;;
    h)
      help
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

# Option sanity check
if [ "$STREAMNUMBER" == "" ]
then
  echo "Specify stream number, option -n"
  help
fi

if [ "$TYPE" == "" ]
then
  echo "Specify stream type, option -t"
  help
fi

if [[ "$TYPE" == "hdpvr" || "$TYPE" == "logitech" ]] && [ "$DEVICE" == "" ]
then
  echo "Specify device, option -d"
  help
fi

# If output port is not an integer then assume it is a file name
if [ "${STREAMNUMBER}" -eq "${STREAMNUMBER}" ] 2>/dev/null
then
	OUTPUTPORT="udp://236.0.0.1:200${STREAMNUMBER}"
else
	OUTPUTPORT="${STREAMNUMBER}"
fi

# echo $TYPE
# echo $STREAMNUMBER
# echo $DEVICE
# echo $OUTPUTPORT
# exit

# Size
# ega 640x350
# hd480 852x480
# VIDEOSIZE=hd480

# If width and height not specified then use defaults
# Type scoreboard is a spceial case - small image!
if [ "$TYPE" == "scoreboard" ]
then
  if [ "$W" == "" ]
  then
    W=208
  fi
  if [ "$H" == "" ]
  then
    H=112
  fi
fi
# Defaults for other types, is. hdpvr, logitech, X11 and test
if [ "$W" == "" ]
then
  W=852
fi
if [ "$H" == "" ]
then
  H=480
fi

# IP for host. Used by the zmq filters. Get first IP
IP=`hostname  -I | cut -f1 -d' '`

# Settings for most input types
VIDEOIN="[0:0]"
OUTPUTMAP="-map [video] -map [audio]"
VIDEOOUTPUTCODEC="-s ${W}x${H} -c:v libx264 -preset ultrafast -pix_fmt yuv420p -r 25 -g 25"
AUDIOOUTPUTCODEC="-c:a aac -b:a 128k -ar 44100 -strict -2"
AUDIORECORDONOFFFILTER="azmq=bind_address=tcp\\\\\\://${IP}\\\\\\:5550,volume=volume=1:eval=frame"

# Specify streams for ffmpeg depending on hardware
if [ "$TYPE" == "hdpvr" ]
then
	# hdpvr has been set to stream in this size
	W=1280
	H=720

	AUDIOIN="[0:1]"
	INPUT="-f mpegts -i ${DEVICE}"
	FILTER="-filter_complex ${VIDEOIN}null[video];${AUDIOIN}${AUDIORECORDONOFFFILTER}[audio]"
elif [ "$TYPE" == "logitech" ]
then
	# Set capture size. Facter of 16!
	W=800
	H=448

	AUDIOIN="[1:a]"
	# INPUT="-f v4l2 -input_format h264 -r 24 -i ${DEVICE} -f alsa -ac 2 -itsoffset +5.0 -i hw:1"
	INPUT="-f v4l2 -input_format h264 -r 24 -i ${DEVICE} -f alsa -ac 2 -itsoffset $AUDIODELAY -i hw:1"
	FILTER="-filter_complex ${VIDEOIN}null[video];${AUDIOIN}${AUDIORECORDONOFFFILTER}[audio]"

	# Disabling autofocus, force absolute focus and set frame size
	# v4l2-ctl --device=${DEVICE} --set-ctrl=focus_auto=0, --set-ctrl=focus_absolute=15, --set-fmt-video=width=${W},height=${H}
	v4l2-ctl --device=${DEVICE} --set-ctrl=focus_auto=0
	v4l2-ctl --device=${DEVICE} --set-ctrl=focus_absolute=15
	v4l2-ctl --device=${DEVICE} --set-fmt-video=width=${W},height=${H}
elif [ "$TYPE" == "X11" ]
then
	# Once the script is running you can enable or disable the overlay
	# by running one of these two commands in a terminal window.
  # echo Parsed_overlay_0 x 0    | zmqsend -b tcp://`hostname  -I | cut -f1 -d' '`:5552
  # echo Parsed_overlay_0 x 9999 | zmqsend -b tcp://`hostname  -I | cut -f1 -d' '`:5552

	# Frame rate is reduced to 5 to improve performance
	R=5
  #INPUT="-re -loop 1 -i /home/tps/Downloads/f2.png \ // don't use - makes merging cpu intensive!
  INPUT="-f lavfi -i color=c=green:s=${W}x${H}:r=${R} \
  -video_size ${W}x${H} -r ${R} -f x11grab -show_region 1 -follow_mouse centered -i :0.0+0,0"
	# Giving x a value of 9999 disables the overlay
	FILTER="-filter_complex \
[0][1]overlay=x=9999:eval=frame,zmq=bind_address=tcp\\\://${IP}\\\:5552[video]"
	OUTPUTMAP="-map [video]"
	# why non-standard value for -g ? VIDEOOUTPUTCODEC="-s ${W}x${H} -c:v libx264 -preset ultrafast -pix_fmt yuv420p -r 25 -g 1"
	AUDIOOUTPUTCODEC=""
elif [ "$TYPE" == "scoreboard" ]
then
	# Set capture size - must be a factor of 16
	W=208
	H=112

	INPUT="-re -loop 1 -i scoreboard.png"

	# Scoreboard font. Font numbers, font text and font color
	FN=/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf
	FT=/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf
	FC=red
	# Font and box
	FB="fontsize=30:fontcolor=red:box=1:boxcolor=black"

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
	OUTPUTMAP="-map [video]"
	AUDIOOUTPUTCODEC=""
	# VIDEOOUTPUTCODEC="-s ${W}x${H} -c:v libx264 -preset ultrafast -pix_fmt yuv420p -r 25 -g 25"
elif [ "$TYPE" == "test" ]
then
  INPUT="-re -f lavfi -i testsrc=size=1280x720 -f lavfi -i sine=frequency=1000"
  FILTER="-filter_complex [0:0]null[video];[1:0]${AUDIORECORDONOFFFILTER}[audio]"
else
  echo "Specify valid type, option -t"
  help
fi

# Handle Ctrl-C.
int_handler()
{
	exit
}
trap 'int_handler' INT

while true; do
	echo -en "\033]2;Stream to LAN (\"${TYPE}\") from ( \"${DEVICE}\"). Size ${W}x${H}. Destination ${OUTPUTPORT}\007"

  # echo "1. ${REPORT}"
	# echo "2. ${INPUT}"
	# echo "3. ${FILTER}"
	# echo "4. ${OUTPUTMAP}"
	# echo "5. ${VIDEOOUTPUTCODEC}"
	# echo "6. ${AUDIOOUTPUTCODEC}"
	# echo "7. ${ONLY1FRAME}"
	# echo "8. ${OUTPUTPORT}"
  # exit

	ffmpeg \
	${REPORT} \
	${INPUT} \
	${FILTER} \
	${OUTPUTMAP} \
	${VIDEOOUTPUTCODEC} \
	${AUDIOOUTPUTCODEC} \
	${ONLY1FRAME} \
	-f mpegts \
	${OUTPUTPORT}

	# Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
