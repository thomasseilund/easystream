#!/bin/bash

while true; do
	NANO=`date +%N`
	echo "Q${NANO:1:1} H: ${NANO:5:2} G: ${NANO:2:2} `date +%M`:`date +%S` ${NANO:4:1}"
	sleep 1
done
