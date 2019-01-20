#!/bin/bash

function help {
  echo "Create a number of terminals"
  echo "Call $0 -n number of terminals"
  exit 0
}

# Get command line options - see http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":n:h" opt; do
  case $opt in
		n)
      NUM=$OPTARG
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

# Constants
WORKDIR=`pwd`

# Parameter sanity check
if [ "$NUM" == "" ]
then
	help
fi

for (( i=1; i <= ${NUM}; i++ ))
do
#	echo $PATH
#	lxterminal --geometry=120x10 --working-directory=$WORKDIR
	qterminal --workdir=$WORKDIR
	#BASHRC_SKIPPS1=true gnome-terminal --title="video record $i" --working-directory=$WORKDIR
done
