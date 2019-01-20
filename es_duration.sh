#!/bin/bash


#22/8/18
# Jeg tror, at det er bedst at capture også encoder en udp-stream. 
# Fremfor kun at capture een stream og så lade ffplay afspille det sidste optagne.
#- udp-stream gør at man er tættere på at se det, der lige er optaget. 
# -Ved afspilning af det sidste optagne, så ser man det, der blev optaget for et par sekunder siden. udp-stream er nærmest 'live' - kun forsinket mindre end et sek.
#- udp-stream er dog i dårligere kvalitet, men det gør ikke noget. Det er jo ikke den stream, der sluttelig broadcast'es
#- cpu-belastning for de to metoder er den samme
#- jeg kan ikke pakke den stream, der lagres i mkv-fil, i udp-stream. Da udp er format mpegts og dette format kan ikke holde mjpeg, som er det codec, der benyttes i mkv-fil.
#- det er en fordel at udp-stream kan ses af alle hosts på nettet.


if [ "$1" == "" ]
then
	let "D = `date +%s` - `cat epoch` - 5"
else
	let "D = `date +%s` - `cat stream$1/epoch` - 5"
fi
echo $D

#echo ffplay -ss $D `ls stream$1/*.mkv | tail -n 1`

#ffplay -autoexit -ss $D `ls stream$1/*.mkv | tail -n 1`
