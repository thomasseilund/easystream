mkdir newdir
cd newdir
PATH=$PATH:~/github/easystream
es_terminal_setup.sh -n 4



Hvis der optages med Logitech så er det en god ide, at teste billede/lyd synkronisering. Set iso.. i es_stream_to_udp.sh

Burn
Find navn for cd-drev
eject /dev/sr0 - hvis skuffe åbner,  så er navn for cd-drev lig /dev/sr0
growisofs -Z /dev/sr0 -r -J /path/to/files


Fokuser kamera

Antag at kamera er på /dev/video2

# brug manuel fokus:
v4l2-ctl -d 2 --set-ctrl=focus_auto=0

# sæt fokus manuelt. Prøv med forskellige værdier, fx. 5,10, 30, 50
v4l2-ctl -d 2 --set-ctrl=focus_absolute=45



Åben en terminal. Alt+F2 - vælg qterminal

Split terminal horizontalt et par gange, så man har fire terminaler i samme vindue

Stop programmer med Ctrl + C

Start qps process monitor, og læg program i bundlinie, så man kan følge med i CPU-belastning

Terminal 1:

Test kamera, fx /dev/video2 Størrelse på video sættes senere

ffplay -i /dev/video2

Terminal 2:

Fokuser. Kun nødvendigt når der ikke er fokusering på kamera. Det er der typisk ikke på webcams

es_fokus -v 2

Terminal 1:161a32935cafa3958f593d4fa36dc48ecb39fcc4

Optag - speed skal komme op på 1

es2_capture.sh -t UVC -n 1 -v 2 -s hd720 -r 24 -a 1 -b

Terminal 2:

Gør klar til at stoppe/starte lydoptagelse. Stop evt. optagelse af lyd til kamp starter

es_on_off.sh

Terminal 3:

Se live optagelse. Forvent lavere kvalitet. Streaming-kvalitet er højere. Optagelse må max være et par sek. bagud

es_play_stream_from_udp.sh -n 1

Terminal 4:

Live stream til YouTube. X1 is YouTube user. X2 is YouTube Stream name/key. Speed skal komme op på 1.
Log på din kanal på YouTube og gå derefter til https://www.youtube.com/features
Vælg "LIVE STREAMING" og find dit "Stream name/key". Tryk på "Reveal" for at se værdi.

es_stream_to_youtube.sh  -n 1 -U X1 -Y X2

Når du har udført kommando ovenfor, så streames til YouTube.

Gå til din kanal på YouTube og check at stream er ok. Optag evt. lyd, hvis du tidligere slog lyd fra.

På YouTube er optagelsen 30s - 60s bagud.

Hvis du ikke kommer op på speed 1, så kan det være fordi CPU er overbelastet. Prøv at benytte browser til at styre YouTube streaming fra en anden host, så 'encoder'-host ikke spilder kræfter på en browser-session.



Simulate overlay:
ffmpeg -re -f lavfi -i testsrc=size=hd720 -f mjpeg udp://localhost:9999



Skab video med bestemt antal frames:
ffmpeg -f lavfi -i testsrc=size=hd720 -frames:v 25 -pix_fmt yuvj420p -f mjpeg 25.mjpeg
ffmpeg -f lavfi -i color=c=green:size=hd720 -frames:v 1 -pix_fmt yuvj420p -f mjpeg 1.mjpeg

Tæl antal frames i video:
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 1.mjpeg

Compile w. zmq:
gcc es_write_frames.c -o es_write_frames -lzmq

Test es_write_frames:
es_write_frames | ffplay -loglevel quiet -f mjpeg -i pipe:0

Drop stderr output from es_write_frames:
es_write_frames 2>/dev/null | ffplay -loglevel quiet -f mjpeg -i pipe:0

Write frames to udp:
es_write_frames | ffmpeg -loglevel quiet -f mjpeg -i pipe:0 -f mjpeg -c copy udp://localhost:9999

See written frames in another process:
ffplay -f mjpeg -i udp://localhost:9999

Analyze streams with ffprobe. List ffprobe output in two files side by side:
pr -m -t 135.txt live30s.txt | less

Analyse video. Get detailed info:
ffprobe -v error -show_format -show_streams live30s.mjpeg

Two ffmpeg commands produce "EOI missing, emulating" message:
ffmpeg -y -f lavfi -i color=c=green:size=hd720 -frames:v 25 -pix_fmt yuvj420p -f mjpeg 25a.mjpeg && ffmpeg -y -i 25a.mjpeg 25b.mjpeg

Piece of captured video is prepared for playback:
ffmpeg -y -i live30s.mkv -f mjpeg -pix_fmt yuvj420p -q:v 1 live30s.mjpeg

Prod es_write_frames:
es_write_frames  -o 8 -b tcp://192.168.0.13:5552 2>/dev/null | ffmpeg -re -f mjpeg -i pipe:0 -f mjpeg -c copy udp://localhost:9999

Get frame count. Slow method required for mjpeg:
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 live30s.mjpeg

es_write_frames - buffer through an extra ffmpeg proces:
es_write_frames -o 8 -b tcp://192.168.0.13:5552 2>/dev/null | ffmpeg -loglevel quiet -f mjpeg -i pipe:0 -f mjpeg -c copy - | ffmpeg -re -f mjpeg -i pipe:0 -f mjpeg -c copy udp://localhost:9999

Extract into individual images:
ffmpeg -y -i ../live30s.mjpeg -f image2 -q:v 1 live30s-%03d.jpeg

Create RAM disk for playback file:
sudo mount tmpfs ./tmp/ -t tmpfs -o size=1G
