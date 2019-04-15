#!/bin/bash

function help {
  echo "Focus camera. First, capture camera to display with \`ffplay -i /dev/video2\` If needed, adjust video input device"
  echo "Call $0 -v 1|2|3.. -h"
  echo "-v video input device. Use es_devices.sh"
  echo "-h show this help text"
  exit 0
}

# IP for host. Used by the zmq filters. Get first IP
IP=`hostname  -I | cut -f1 -d' '`
ZMQSEND=zmqsend

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":v:h" opt; do
  case $opt in
	v)
	VDEVICE=$OPTARG
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

if [ "$VDEVICE" == "" ]
then
	echo "Specify video device, option -v"
	help
fi

FOCUS=10
ZOOM=100


while true; do
	echo -en "\033]2;ON - OFF - Overlay\007"

  read -n 1 -p "0. Manuel focus. 1. Auto focus. 2, 3 Change focus. Zoom 4, 5 : " CMD
   		echo

   if [ "$CMD" == "0" ]; then
     echo "Try set manuel focus"
     v4l2-ctl -d $VDEVICE --set-ctrl=focus_auto=0
   elif [ "$CMD" == "1" ]; then
     echo "Try set auto focus"
     v4l2-ctl -d $VDEVICE --set-ctrl=focus_auto=1
   elif [ "$CMD" == "2" ]; then
   		NEWFOCUS=$(($FOCUS-1))
       echo "Change focus from $FOCUS to $NEWFOCUS"
       FOCUS=$NEWFOCUS
       v4l2-ctl -d 2 --set-ctrl=focus_absolute=$FOCUS
   elif [ "$CMD" == "3" ]; then
   		NEWFOCUS=$(($FOCUS+1))
       echo "Change focus from $FOCUS to $NEWFOCUS"
       FOCUS=$NEWFOCUS
       v4l2-ctl -d 2 --set-ctrl=focus_absolute=$FOCUS
   elif [ "$CMD" == "4" ]; then
   		NEWZOOM=$(($ZOOM-1))
       echo "Change zoom from $ZOOM to $NEWZOOM"
       ZOOM=$NEWZOOM
       v4l2-ctl -d 2 --set-ctrl=zoom_absolute=$ZOOM
   elif [ "$CMD" == "5" ]; then
   		NEWZOOM=$(($ZOOM+1))
       echo "Change zoom from $ZOOM to $NEWZOOM"
       ZOOM=$NEWZOOM
       v4l2-ctl -d 2 --set-ctrl=zoom_absolute=$ZOOM
   fi
done
