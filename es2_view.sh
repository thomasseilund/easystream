#bin/bash

# Calls:
# Camera 1: (game camera)
# es2_capture.sh -t UVC -n 1 -v 1 -s hd720 -r 24 -a 1
# Scoreboard:
# es2_capture.sh -t scoreboard -n 2 -v 1

#
# Help
#

function help {
	echo "View stream"
	echo "Call $(basename $0) -n 1|2|3... -h -V -R"
	echo "-n stream number. Streams for this number are stored in seperate directory"
	echo "-V verbose"
	echo "-h help - this text"
	echo "-R ffmpeg report"
	exit 0
}

#
# Init variables
#


#
# Handle command line arguments. See http://wiki.bash-hackers.org/howto/getopts_tutorial
#

while getopts "n:VhR" opt; do
case $opt in
	n)
	STREAMNUMBER=$OPTARG
	;;
	V)
	set -x
	;;
	h)
	help
	;;
	R)
      REPORT="-report"
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

#if [ "$STREAMNUMBER" == "" ] 
#then
#	echo "Specify stream number, option -n"
#	help
#fi

# Stream number must be an integer
if [ "$STREAMNUMBER" == "" ] || ! [ "${STREAMNUMBER}" -eq "${STREAMNUMBER}" ] 2>/dev/null
then
	echo "Specify stream number, option -n"
	help
fi


#
# Handle Ctrl-C.
#
int_handler()
{
	exit
}
trap 'int_handler' INT

#
# View until ctrl+c
#

while true; do
	echo -en "\033]2;View stream (\"${STREAMNUMBER}\")\007"

	tail -f `ls stream${STREAMNUMBER}/*.mkv | tail -n 1` | ffplay -fflags nobuffer -f mjpeg -i pipe:0

	# Why did view stop?
	echo -en "\r" `date +"%Y-%m-%d %H:%M:%S,%3N"` "ffmpeg ended with $?. Respawning" >&2

	# Wait and giver user a chance to Ctrl + c
	sleep 5
done
