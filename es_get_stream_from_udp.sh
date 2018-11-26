#!/bin/bash

function help {
  echo "Get a stream from UDP and save it on disk as 'streamnumber'.ts, ie. 1.ts"
  echo "Call $0 -n 1|2|3 -r -h"
  echo "-n streamnumber -r ffmpeg report -h help"
  exit 0
}

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":n:rh" opt; do
  case $opt in
		n)
      STREAMNUMBER=$OPTARG
      ;;
		r)
      REPORT="-report"
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
# Option sanity check
if [ "$STREAMNUMBER" == "" ]
then
  echo "Specify stream number, option -n"
  help
fi

while true; do
	echo -en "\033]2;Get stream udp://236.0.0.1:200${STREAMNUMBER} from LAN. Output ${STREAMNUMBER}.ts\007"

	ffmpeg \
	${REPORT} \
	-y \
  -fflags nobuffer \
	-f mpegts -i udp://236.0.0.1:200${STREAMNUMBER} \
	-c copy \
	-f mpegts \
	${STREAMNUMBER}.ts

	# Why did endoding stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
