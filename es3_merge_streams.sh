#bin/bash

set -x

#ffplay -f mjpeg -i <(tail -f `ls ./stream1/*.mkv | tail -n 1` 2>/dev/null)
#ffmpeg -f mjpeg -i <(tail -f `ls ./stream1/*.mkv | tail -n 1`) -f mjpeg -i <(tail -f `ls ./stream2/*.mkv | tail -n 1`) -filter_complex overlay=y=H-h:eof_action=endall -c:v mjpeg -q:v 1 -c:a copy stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv
#ffplay -i <(tail -f `ls ./stream1/*.mkv | tail -n 1`)
#ffplay -i <(ffmpeg -i `ls ./stream1/*.mkv | tail -n 1` -c copy -)

# Seek and merge
#ffmpeg \
#-re \
#-f mjpeg \
#-sseof -1 \
#-i `ls ./stream1/*.mkv | tail -n 1` \
#-re \
#-f mjpeg \
#-sseof -1 \
#-i `ls ./stream2/*.mkv | tail -n 1` \
#-filter_complex overlay=y=H-h:eof_action=endall \
#-c:v mjpeg \
#-q:v 1 \
#-c:a copy \
#stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv


# No seek. So start merge as fast as possible
if ( false )
then
ffmpeg \
-re \
-f mjpeg \
-i `ls ./stream1/*.mkv | tail -n 1` \
-re \
-f mjpeg \
-i `ls ./stream2/*.mkv | tail -n 1` \
-filter_complex overlay=y=H-h:eof_action=endall \
-c:v mjpeg \
-q:v 1 \
-c:a copy \
stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv
fi


# No seek. Merge when both video streams are in same file
if ( true )
then
	ffmpeg \
	-f mjpeg \
	-i `ls ./stream1/*.mkv | tail -n 1` \
	-filter_complex '[0:0]null[video0]; [0:1]null[video1]; [video0][video1]overlay=y=H-h:eof_action=endall' \
	-c:v mjpeg \
	-q:v 1 \
	-c:a copy \
	stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv
fi


# Stream to UDP and merge
#I1=`ls ./stream1/*.mkv | tail -n 1`
#I2=`ls ./stream2/*.mkv | tail -n 1`
#tail -f ${I1} | ffmpeg -f mjpeg -i - -f mpegts udp://236.0.0.1:2001 &
#tail -f ${I2} | ffmpeg -f mjpeg -i - -f mpegts udp://236.0.0.1:2002 &
#ffmpeg \
#-re \
#-f mpegts \
#-i udp://236.0.0.1:2001 \
#-re \
#-f mpegts \
#-i udp://236.0.0.1:2002 \
#-filter_complex overlay=y=H-h:eof_action=endall \
#-c:v mjpeg \
#-q:v 1 \
#-c:a copy \
#stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv




#ffmpeg -f mjpeg -i <(tail -f `ls ./stream1/*.mkv | tail -n 1`) -f mjpeg -i <(tail -f `ls ./stream2/*.mkv | tail -n 1`) -filter_complex overlay=y=H-h:eof_action=endall -c:v mjpeg -q:v 1 -c:a copy stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv
#ffmpeg -f mjpeg -i <(tail -f `ls ./stream1/*.mkv | tail -n 1`) -f mjpeg -i <(tail -f `ls ./stream2/*.mkv | tail -n 1`) -filter_complex overlay=y=H-h:eof_action=endall -c:v mjpeg -q:v 1 -c:a copy stream9/`date +"%Y.%m.%d-%H:%M:%S.%N"`.mkv


