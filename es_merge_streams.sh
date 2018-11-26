#!/bin/bash -x

function help {
  echo "Read from end of disk files 1.ts, 2.ts and 3.ts and create final.ts"
  echo "1.ts is main camera. 2.ts is gameclock. 3.ts is overlay"
  echo "2.ts can be delayed relative to 1.ts by option -d"
  echo "Call $0 -d delay -r -h"
  echo "-r ffmpeg report -h help"
  exit 0
}

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

# hd480 	852×480
# hd720 	1280×720
# hd1080 	1920×1080
W=852
H=480
# if [ "$SIZE" == "hd480" ]
# then
#   W=852
#   H=480
# fi
# if [ "$SIZE" == "hd720" ]
# then
#   W=1280
#   H=720
# fi
# if [ "$SIZE" == "hd1080" ]
# then
#   W=1920
#   H=1080
# fi

# We must have 1.ts
DURATION1=`ffprobe -show_streams 1.ts | grep duration= | head -n 1 | awk -F'=' '{print $2}'`
INPUT1="-f mpegts -re -ss ${DURATION1} -i 1.ts"

if [ -e "2.ts" ] && [ -e "3.ts" ]
then
  # We have 1.ts, 2.ts and 3.ts
FILTER="-filter_complex \
[2:0]setpts=PTS+${DELAY}/TB[scoreboard];\
[3:0]chromakey=green:0.1:0.0[X11];\
[1:0][scoreboard]overlay=eof_action=endall:y=main_h-overlay_h[gamewithclock];\
[gamewithclock][X11]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2[video]"
  DURATION2=`ffprobe -show_streams 2.ts | grep duration= | head -n 1 | awk -F'=' '{print $2}'`
  DURATION3=`ffprobe -show_streams 3.ts | grep duration= | head -n 1 | awk -F'=' '{print $2}'`
  INPUT2="-f mpegts -re -ss ${DURATION2} -i 2.ts"
  INPUT3="-f mpegts -re -ss ${DURATION3} -i 3.ts"
elif [ -e "2.ts" ]
then
  # We have 1.ts and 2.ts
FILTER="-filter_complex \
[2:0]setpts=PTS+${DELAY}/TB[scoreboard];\
[1:0][scoreboard]overlay=eof_action=endall:y=main_h-overlay_h[video]"
  DURATION2=`ffprobe -show_streams 2.ts | grep duration= | head -n 1 | awk -F'=' '{print $2}'`
  INPUT2="-f mpegts -re -ss ${DURATION2} -i 2.ts"
elif [ -e "3.ts" ]
then
  # We have 1.ts and 3.ts
FILTER="-filter_complex \
[2:0]setpts=PTS+${DELAY}/TB[scoreboard];\
[1:0][scoreboard]overlay=eof_action=endall:y=main_h-overlay_h[video]"
  DURATION3=`ffprobe -show_streams 3.ts | grep duration= | head -n 1 | awk -F'=' '{print $2}'`
  INPUT3="-f mpegts -re -ss ${DURATION3} -i 3.ts"
fi

sleep 4.0

while true; do
  echo -en "\033]2;Merge streams. Delay = ${DELAY} Output to final.ts\007"

  ffmpeg \
  ${REPORT} \
  -y \
  -f lavfi -i color=c=black:s=${W}x${H} \
  ${INPUT1} \
  ${INPUT2} \
  ${INPUT3} \
  ${FILTER} \
  -f mpegts \
  -map [video] \
  -map 1:a \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -r 25 -g 25 \
  -c:a copy \
  -f mpegts \
  final.ts

  # Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
