#!/bin/bash

function help {
	echo "Stream final.ts to YouTube. "
	echo "NO - Stream from end of stream identified by stream number to YouTube. "
	echo "Call $0 -r 1|2|3 -c 0-51 -s 1|2"
	echo "-n stream number. Streams for this number are stored in seperate directory"
	echo "-r, resolution 1    : 640x360"
	echo "-r, resolution 2    : 854x480, default"
	echo "-r, resolution 3    : 1280x720"
	echo "-c, cfr : 0-51. 0 Lossless, 18 Perceived lossless. 23 Sane value, default. 51 Worst quality"
	echo "-s, youtubeserver 1 : normal, default"
	echo "-s, youtubeserver 2 : backup"
	echo "-U, youtubestreamUser"
	echo "-Y, youtubestream. Get from https://www.youtube.com/features then select \"LIVE STREAMING\" and then \"Stream name/key\""
	exit 0
}

# Default values for options
RESOLUTION=2
CRF=23
YOUTUBESERVERTOUSE=1

# Get command line options
while getopts ":r:c:s:n:Y:U:h" opt ; do
	case $opt in
		n)
			STREAMNUMBER=$OPTARG
			;;
		Y)
			YOUTUBESTREAM=$OPTARG
			;;
		U)
			YOUTUBESTREAMUSER=$OPTARG
			;;
		r)
			RESOLUTION=$OPTARG
			;;
		c)
			CRF=$OPTARG
			;;
		s)
			YOUTUBESERVERTOUSE=$OPTARG
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

#
# Option sanity check
#

if [ "$STREAMNUMBER" == "" ]
then
	echo "Specify stream number, option -n"
	help
fi

if [ "$YOUTUBESTREAMUSER" == "" ]
then
	echo "Specify YouTube user, option -U"
	help
fi

if [ "$YOUTUBESTREAM" == "" ]
then
	echo "Specify YouTube Stream name/key, option -Y"
	help
fi


# Constants
GOP="50"
YOUTUBESERVER01="rtmp://a.rtmp.youtube.com/live2"
YOUTUBESERVER02="rtmp://b.rtmp.youtube.com/live2?backup=1"

if [ "$RESOLUTION" == "1" ]
then
	# For H="360"
	FRAMESIZE="640x360"
elif [ "$RESOLUTION" == "2" ]
then
	# For H="480"
	FRAMESIZE="854x480"
elif [ "$RESOLUTION" == "3" ]
then
	# For H="720"
	FRAMESIZE="1280x720"
else
	echo "Invalid value for resolution, -r: " $RESOLUTION
	help
fi

# Stream Now (YouTube Live) thomasseilund.apbz-gsmt-tuma-2z07
if [ "$YOUTUBESERVERTOUSE" == "1" ]
then
	# normal server
	YOUTUBESERVER=$YOUTUBESERVER01
elif [ "$YOUTUBESERVERTOUSE" == "2" ]
then
	# backup server
	YOUTUBESERVER=$YOUTUBESERVER02
else
	echo "Invalid value for youtube server, -s: " $YOUTUBESERVERTOUSE
	help
fi

# 1. vers. Stream final.ts
#while true ; do
#	# echo -en "\033]2;final.ts to YouTube, ${YOUTUBESERVER}/${YOUTUBESTREAM}, size $FRAMESIZE\007"
#	echo -en "\033]2;final.ts to YouTube, size $FRAMESIZE\007"
#	tail -f final.ts | \
#	ffmpeg -y -i - \
#	-c:v libx264 -crf ${CRF} -pix_fmt yuv420p -g ${GOP} \
#	-s $FRAMESIZE \
#	-c:a aac -b:a 128k -ar 44100 -strict -2 \
#	-f flv ${YOUTUBESERVER}/${YOUTUBESTREAM}
#	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2
#	sleep 5
#done

# 2. vers. Stream from end of stream number $STREAMNUMBER, ie ./stream$STREAMNUMBER/2018---.mkv
while true ; do
	INPUT=`ls stream$STREAMNUMBER/*.mkv | tail -n 1`
	if [ "$INPUT" == "" ]
	then
		echo "Can't find *.mkv file in ./stream$STREAMNUMBER"
		help
	fi
	DURATION=`es_duration.sh $STREAMNUMBER`
	echo -en "\033]2;$INPUT to YouTube, size $FRAMESIZE\007"
	ffmpeg -re -ss $DURATION -i $INPUT \
	-c:v libx264 -crf ${CRF} -pix_fmt yuv420p -g ${GOP} \
	-s $FRAMESIZE \
	-c:a aac -b:a 128k -ar 44100 -strict -2 \
	-f flv ${YOUTUBESERVER}/${YOUTUBESTREAMUSER}.${YOUTUBESTREAM}
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2
	sleep 5
done
