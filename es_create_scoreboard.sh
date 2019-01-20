#!/bin/bash

function help {
  echo "Build an image file that looks like a scoreboard"
  echo "Call $0 -a hometeam -b awayteam -1 homelogo -2 awaylogo -t gametext -h"
  echo "Use Image Magick to get logo right size, ie. convert origlogo.png -geometry 32x logo32.png
  exit 0
}

# Constants
# Scoreboard size
BW=200
BH=100
# Scoreboard font
FONTFILENUMBERS=/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf
FONTFILETEXT=/usr/share/fonts/truetype/freefont/FreeMonoBold.ttf
FONTFILENUMBERS=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
FONTFILETEXT=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
FONTCOLOR=red

# Get command line options
while getopts ":a:b:t:1:2:s:h" opt ; do
	case $opt in
		a)
			TEAMHOME=$OPTARG
			;;
		b)
			TEAMAWAY=$OPTARG
			;;
		t)
			TEXT=$OPTARG
			;;
		1)
			HOMELOGO=$OPTARG
			;;
		2)
			AWAYLOGO=$OPTARG
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

# Sanity check of line parameters
if ! [ -f $HOMELOGO ]
then
	echo Home logo file not found - $HOMELOGO
	help
	exit 1
fi
if ! [ -f $AWAYLOGO ]
then
	echo Guest logo file not found - $AWAYLOGO
	help
	exit 1
fi

# Contruct scoreboard graphics by calling ImageMagich function convert
convert -size ${BW}x${BH} xc:gray b1.png
if [ "$?" != "0" ]
then
	echo Is ImageMagick installed?
	echo Run command \"sudo apt-get install imagemagick\" and try again!
	exit
fi
convert -geometry 90%x70% b1.png b2.png
convert -geometry 40%x25% b1.png b3.png
convert -border 3% -bordercolor white b2.png b2b.png
convert -border 3% -bordercolor white b3.png b3b.png
composite -gravity north b3b.png b2b.png b4.png
# Create home and away logo if not specified
if [ "$HOMELOGO" == "" ]
then
	HOMELOGO=bhomelogo.png
	convert -size 32x32 xc:white $HOMELOGO
fi
composite -geometry +10+4 $HOMELOGO b4.png b5.png
if [ "$AWAYLOGO" == "" ]
then
	AWAYLOGO=bawaylogo.png
	convert -size 32x32 xc:blue $AWAYLOGO
fi
composite -geometry +145+4 $AWAYLOGO b5.png b6.png
convert b6.png -font $FONTFILETEXT -pointsize 18 -draw "text  15,46  '$TEAMHOME'" b7.png
convert b7.png -font $FONTFILETEXT -pointsize 18 -draw "text  145,46 '$TEAMAWAY'" b8.png
composite -gravity south b8.png b1.png b9.png
convert b9.png -font $FONTFILETEXT -pointsize 22 -gravity north -draw "text 0,0 '$TEXT'" scoreboard.png

# tps 17/6/16. I have seen that in some cases ffmpeg filter does not work. But if scoreboard.png
# is converted to scoreboard.jpg and back again then it works!
convert scoreboard.png scoreboard.jpg
convert scoreboard.jpg scoreboard.png
rm scoreboard.jpg

# Delete temp image files
rm b*.png
