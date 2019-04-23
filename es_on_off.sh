#!/bin/bash

#
# Defaults
#

CAM1_OVERLAY=19
CAM2_OVERLAY=21



function help {
  echo "Control show of overlay created in call es_stream_to_upd -t X11"
  echo "Control audio record in call es_stream_to_upd -t logitech|hdpvr"
  echo "Call $0 -i 1.2.3.4 -p zmqsend -h"
  echo "-i ip of host running es_stream. Default is local host"
  echo "-p full path and name of zmqsend. Use if zmqsend is not on path"
  echo "-h show this help text"
  echo "-V verbose, bash script"
  exit 0
}

# IP for host. Used by the zmq filters. Get first IP
IP=`hostname  -I | cut -f1 -d' '`
ZMQSEND=zmqsend

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":i:p:hV" opt; do
  case $opt in
    i)
      IP=$OPTARG
      ;;
    p)
      ZMQSEND=$OPTARG
      ;;
    V)
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

while true; do
	echo -en "\033]2;ON - OFF - Overlay\007"
  # read -n 1 -p "1. Activate overlay. 2. Deactivate overlay : 3. Enable audio record : 4. Disable audio record : " CMD
  #read -n 1 -p "0. Cam 0`echo $'\n'` 1. Cam 1`echo $'\n> '`: 3. Enable audio record : 4. Disable audio record : " CMD
  echo 0 Cam 0
  echo 1 Cam 1
  echo 2 Cam 2
  read -n 1 -p "> " CMD
  echo

  if [ "$CMD" == "0" ]; then
    echo "Camera 0"
    echo Parsed_overlay_${CAM1_OVERLAY} x 9999      | ${ZMQSEND} -b tcp://${IP}:5552
    echo Parsed_overlay_${CAM2_OVERLAY} x 9999      | ${ZMQSEND} -b tcp://${IP}:5552
  elif [ "$CMD" == "1" ]; then
    echo "Camera 1"
    echo Parsed_overlay_${CAM1_OVERLAY} x \(W-w\)/2 | ${ZMQSEND} -b tcp://${IP}:5553
    echo Parsed_overlay_${CAM2_OVERLAY} x 9999      | ${ZMQSEND} -b tcp://${IP}:5553
  elif [ "$CMD" == "2" ]; then
    echo "Camera 2"
    echo Parsed_overlay_${CAM1_OVERLAY} x 9999      | ${ZMQSEND} -b tcp://${IP}:5554
    echo Parsed_overlay_${CAM2_OVERLAY} x \(W-w\)/2 | ${ZMQSEND} -b tcp://${IP}:5554
  # elif [ "$CMD" == "3" ]; then
  #   echo "Try enable audio record"
  #   echo Parsed_volume_2 volume 1 | ${ZMQSEND} -b tcp://${IP}:5550
  # elif [ "$CMD" == "4" ]; then
  #   echo "Try disable audio record"
  #   echo Parsed_volume_2 volume 0 | ${ZMQSEND} -b tcp://${IP}:5550
  fi
done
