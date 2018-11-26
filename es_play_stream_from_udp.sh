#!/bin/bash

function help {
  echo "Play a stream from UDP. Stream must already be started with es_stream_to_udp"
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
if [ "$STREAMNUMBER" == "" ]
then
  echo "Specify stream number, option -n"
  help
fi

echo -en "\033]2;Play stream from udp://236.0.0.1:200${STREAMNUMBER}\007"

ffplay $REPORT -fflags nobuffer -i udp://236.0.0.1:200${STREAMNUMBER}
