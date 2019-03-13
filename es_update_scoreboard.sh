#!/bin/bash

function help {
	echo "Control numbers shown in scoreboard in call es_stream_to_upd -t scoreboard"
	echo "Call $0 -i 1.2.3.4 -p zmqsend -h"
	echo "-i ip of host running es_stream, if not local host -p full path and name of zmqsend, use if zmqsend is not on path -h"
	echo "-V verbose"
	echo "For test use \"es_test_data_to_scoreboard.sh | es_update_scoreboard.sh\""
	exit 0
}

# Local host
IP=`hostname  -I | cut -f1 -d' '`
# zmqsend program
ZMQSEND=zmqsend
SCOREBOARD_PORT=5551

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":i:p:hxV" opt; do
  case $opt in
    i)
      IP=$OPTARG
      ;;
    p)
      ZMQSEND=$OPTARG
      ;;
    x)
      set -x
      ;;
		h)
			help
      ;;
		V)
			set -x
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

L=0
while read LINE
do
	# Nautronic scoreboard prints lines to std out in this format
	#	printf("Q%d H: %02d G: %02d %02d:%02d %02d\n",quarter, home, guest, minute, second, shotclock);
	#Q0 H: 34 G: 80 17:04 34

	# Index på Parsed_drawtext_3, i det her tilfælde index 3, svarer til filternummer. Hvis jeg har en filtergraf, hvor der er
	# et 'null' og et 'volumne' filter før det første drawtext-filter, så starter index med ... Det her fårstår jeg ikke helt!!!
	# Jeg har ændret index fra 0 - 5 og over til 3 - 8. Det var nødvendigt, hvis jeg ville lægger både game-video, audio og
	# scoreboard i samme strøm.


	#01234567890123456789012
	((L++))
	if [ "$L" == "1" ]
	then
		# Extract values
		MINUTE=${LINE:15:2}
		SECOND=${LINE:18:2}
		QUARTER=${LINE:1:1}
		HOMESCORE=${LINE:6:2}
		SHOTCLOCK=${LINE:21:2}
		AWAYSCORE=${LINE:12:2}
		# Update terminal window title
		echo -en "\033]2;$QUARTER Qrt. Home $HOMESCORE Away $AWAYSCORE ${MINUTE}:${SECOND} $SHOTCLOCK\007"
		echo ${LINE}
		# Send values to instance of ffmpeg creating the scoreboard
		echo Parsed_drawtext_5 reinit text=${MINUTE}		| ${ZMQSEND} -b tcp://${IP}:${SCOREBOARD_PORT}
		echo Parsed_drawtext_6 reinit text=${SECOND}		| ${ZMQSEND} -b tcp://${IP}:${SCOREBOARD_PORT}
		echo Parsed_drawtext_7 reinit text=${QUARTER}		| ${ZMQSEND} -b tcp://${IP}:${SCOREBOARD_PORT}
		echo Parsed_drawtext_8 reinit text=${HOMESCORE}	| ${ZMQSEND} -b tcp://${IP}:${SCOREBOARD_PORT}
		echo Parsed_drawtext_9 reinit text=${SHOTCLOCK}	| ${ZMQSEND} -b tcp://${IP}:${SCOREBOARD_PORT}
		echo Parsed_drawtext_10 reinit text=${AWAYSCORE}	| ${ZMQSEND} -b tcp://${IP}:${SCOREBOARD_PORT}
		L=0
	fi
done
