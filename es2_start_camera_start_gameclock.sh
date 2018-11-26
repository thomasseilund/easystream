#bin/bash

set -x

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f $0)
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`

if ( false )
then

ffmpeg -y -f v4l2 -thread_queue_size 32 -input_format mjpeg -s hd720 -r 24 -i /dev/video1 -f alsa -thread_queue_size 32 -i hw:1 -filter_complex '[0:0]null[video];[1:0]azmq=bind_address=tcp\\\://192.168.0.15\\\:5550,volume=volume=1:eval=frame[audio]' -map '[video]' -map '[audio]' -c:v mjpeg -q:v 1 -r 25 -c:a aac -b:a 128k -ar 44100 -strict -2 ./stream1/s1.mkv < /dev/null &

ffmpeg -y -re -loop 1 -i scoreboard.png -filter_complex '[0:0]drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=11:x=63:y=25+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=22:x=101:y=25+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=3:x=200/2-text_w/2:y=50+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=44:x=25:y=72+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=55:x=(200-text_w)/2:y=72+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=66:x=140:y=72+main_h-100,zmq=bind_address=tcp\\://192.168.0.15\\:5551[video]' -map '[video]' -c:v mjpeg -q:v 1 -r 25 ./stream2/s2.mkv  < /dev/null

fi

if ( false )
then
	ffmpeg -y \
	-f v4l2 -thread_queue_size 32 -input_format mjpeg -s hd720 -r 24 -i /dev/video1 \
	-f alsa -thread_queue_size 32 -i hw:1 \
	-re -loop 1 -i scoreboard.png \
	-filter_complex '[0:0]null[video0]; [1:0]azmq=bind_address=tcp\\\://192.168.0.15\\\:5550,volume=volume=1:eval=frame[audio];[2:0]drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=11:x=63:y=25+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=22:x=101:y=25+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=3:x=200/2-text_w/2:y=50+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=44:x=25:y=72+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=55:x=(200-text_w)/2:y=72+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=66:x=140:y=72+main_h-100,zmq=bind_address=tcp\\://192.168.0.15\\:5551[video1]' \
	-map '[video0]' -map '[video1]' -map '[audio]' -c:v mjpeg -q:v 1 -r 25 -c:a aac -b:a 128k -ar 44100 -strict -2 ./stream1/s1.mkv

	# Den strøm, der skabes her holder to videoer. Disse kan overlay'es med:
	# ffmpeg -i ./stream1/s1.mkv -filter_complex '[0:0][0:1]overlay=y=H-h:eof_action=endall' -c:v mjpeg -q:v 1 -c:a copy stream9/s9.mkv

fi


# capture og overlay i samme ffmpeg kald
if ( false )
then
	ffmpeg -y \
	-f v4l2 -thread_queue_size 32 -input_format mjpeg -s hd720 -r 24 -i /dev/video1 \
	-f alsa -thread_queue_size 32 -i hw:1 \
	-re -loop 1 -i scoreboard.png \
	-filter_complex '[0:0]null[video0]; [1:0]azmq=bind_address=tcp\\\://192.168.0.15\\\:5550,volume=volume=1:eval=frame[audio];[2:0]drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=11:x=63:y=25+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=22:x=101:y=25+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=3:x=200/2-text_w/2:y=50+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=44:x=25:y=72+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=55:x=(200-text_w)/2:y=72+main_h-100,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontsize=30:fontcolor=red:box=1:boxcolor=black:text=66:x=140:y=72+main_h-100,zmq=bind_address=tcp\\://192.168.0.15\\:5551[video1]; [video0][video1]overlay=y=H-h:eof_action=endall[video2]' \
	-map '[video2]' -map '[audio]' -c:v mjpeg -q:v 1 -r 25 -c:a aac -b:a 128k -ar 44100 -strict -2 ./stream1/s1.mkv
fi


echo $0


# capture og overlay i samme ffmpeg kald. Nu med filter i særskilt scritp fil
if ( true )
then
	ffmpeg -y \
		-f v4l2 -thread_queue_size 32 -input_format mjpeg -s hd720 -r 24 -i /dev/video1 \
		-f alsa -thread_queue_size 32 -i hw:1 \
		-re -loop 1 -i scoreboard.png \
		-filter_complex_script ${SCRIPTPATH}/es2_start_camera_start_gameclock.filterscript \
		-map '[video2]' -map '[audio]' -c:v mjpeg -q:v 1 -r 25 -c:a aac -b:a 128k -ar 44100 -strict -2 ./stream1/s1.mkv
fi