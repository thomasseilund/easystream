#bin/bash
#

# Handle Ctrl-C.
int_handler()
{
	exit
}
trap 'int_handler' INT

#while true; do

	# Tell HDPVR to capture composite video and audio from the front panel
	v4l2-ctl -d 1 -i 2
	v4l2-ctl -d 1 --set-audio-input 1

	set -x
	ffmpeg -f mpegts -i /dev/video1 -c copy -f mpegts `date +"p%Y-%m-%d-%H-%M-%S-%N.ts"`
	set +x

	# Wait and giver user a chance to Ctrl + c
	sleep 1

#done
