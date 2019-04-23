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

Create video of scoreboard:
Med -re og loop på jpg af scoreboard så er ffmpeg lang tid om at komme op på 1.0 hastighed.
Derfor laves video af scoreboard. Det nytter ikke at have loop-filter over en enkelt frame,
for så kommer tal for scoreboard ikke ind!
ffmpeg -f mjpeg -i scoreboard.mjpeg -vf loop=loop=100000:size=1:start=0 -q:v 1 -f mjpeg scoreboard100.mjpeg

ffplay with on display text:
ffplay -loglevel quiet -vf "drawtext=fontsize=30:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:text='%{pts\:hms}':box=1:x=(w-tw)/2:y=h-(2*lh)" -i stream/2019.03.15-18-04-02.mkv

extract video:
ffmpeg -y -ss 45.34 -i stream/2019.03.15-14-16-45.mkv -map 0:v -t 44.23 -f mjpeg -c copy exract.mjpeg

copy adjusted version of ffplay.c before commit:
cp ~/ffmpeg_sources/ffmpeg/fftools/ffplay.c ~/github/easystream/

USB over IP:
http://www.linux-magazine.com/Issues/2018/208/Tutorial-USB-IP
https://www.makeuseof.com/tag/usb-over-ethernet/

Test - create two track output:
ffmpeg -f v4l2 -thread_queue_size 64 -input_format mjpeg -s vga -r 24 -i /dev/video0 -f alsa -thread_queue_size 64 -i hw:1 -f v4l2 -thread_queue_size 64 -input_format mjpeg -s vga -r 25 -i /dev/video2 -filter_complex '[0:0]setpts=PTS-STARTPTS,fps=25[cam];[1:0]anull[audio];[cam]null[videores];[videores]split[video][videox];[2:0]setpts=PTS-STARTPTS,fps=25[cam2]' -map '[video]' -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -map '[audio]' -c:a aac -b:a 128k -ar 44100 -strict -2 -map '[cam2]' -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -y -f matroska twotracks.mkv -map '[videox]' -f xv -pix_fmt yuv420p display

More info on muxer - a live option exists!!!
ffmpeg -h muxer=matroska

USB over IP:
https://developer.ridgerun.com/wiki/index.php?title=How_to_setup_and_use_USB/IP

HDMI -> x264 over IP:
2019 ZY-DT209 RJ45 HDMI Extender IP Over UTP/STP CAT5 CAT5e CAT6 Extensor HDMI With IR LAN Network 200m HDMI Extender Ethernet
https://www.aliexpress.com/item/2019-ZY-DT209-RJ45-HDMI-Extender-IP-Over-UTP-STP-CAT5-CAT5e-CAT6-Extensor-HDMI-With/32844800482.html?spm=2114.search0204.3.8.3db64dfcTZsxtI&s=p&ws_ab_test=searchweb0_0,searchweb201602_5_10065_10068_319_10059_10884_317_10887_10696_321_322_10084_453_10083_454_10103_10618_10304_10307_10820_10821_537_10302_536_10902,searchweb201603_51,ppcSwitch_0&algo_expid=f7698204-8ef3-4b62-8ad8-4059e26775da-1&algo_pvid=f7698204-8ef3-4b62-8ad8-4059e26775da&transAbTest=ae803_4
https://navceker.aliexpress.com/store/3372034
https://navceker.aliexpress.com/store/seller-store-story/3372034.html

reset alsa:
sudo alsa force-reload

reset uvc:
sudo rmmod uvcvideo && sudo modprobe uvcvideo

No space left on device:
Not enough USB bandwidth on the controller

Capture from UVC and for input in one terminal and play back in another:
ffmpeg -y -f v4l2 -framerate 15 -input_format mjpeg -video_size hd720 -i /dev/video0 -filter_complex '[0:0]setpts=PTS-STARTPTS,fps=25[cam1]' -map '[cam1]' -pix_fmt yuvj420p -f mjpeg buildin.mjpeg
tail -c 256 -f buildin.mjpeg | full_frame_mjpeg > playback/playback.mjpeg

hex viewer:
xxd test.mjpeg | select_streams

Der er optaget fra 3 kameraer og gemt i fil. Sidste kam tager mindre billeder end de to første. Vis tre kameraoer ved siden af hinanden:
ffmpeg -y -i stream/`ls stream | tail -n 1` \
-filter_complex "[0:v:0]scale=hd720[v0];[0:v:1]scale=hd720[v1];[0:v:2]scale=hd720[v2];[0:v:3]scale=hd720[v3];[0:v:4]scale=hd720[v4];[v0][v1][v2][v3][v4]hstack=5[video];[0:a]anull[audio]" \
-map [video] -map [audio] -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -c:a aac -b:a 128k -ar 44100 -strict -2 test.mkv
ffplay -i test.mkv

Linux UVC homepage:
http://www.ideasonboard.org/uvc/

Lower FPS when little light:
FPS depends on exposure. The longer exposure is the slower the FPS is.

See all options for UVC camera:
v4l2-ctl -d 2 --help-all | less

fps afhænger af lys. Logitech c920 er op /dev/video2. Kør:
ffmpeg -y -f v4l2 -input_format mjpeg -r 30 -i /dev/video2 -f alsa -thread_queue_size 1024 -i hw:2 -c copy test.mkv
Noter, at fps rappoteret af ffmpeg afhænger af lys i lokalet. Med lidt lys rapporteres 15 fps. Med mere lys, så bevæger fps sig mod 30 (som er den ønskede fps)
Med meget lys, så er fps 30 fra starten!
Bemærk, at fps er fps skrevet til output fil. Ikke fps taget fra input fil!
Er det mon sådan at exposure tilpasses lyset så med lidt lys øges exposure og fps går ned og omvendt?
Sådan opfører det interne kamera på T420 sig ikke. Der er altid 30 fps uanset lysstyrke.
Kør:
v4l2-ctl -d 2 -L
Se værdi for exposure_auto. Den vil nok være 3 for auto!
Kør:
v4l2-ctl -d 2 --set-ctrl=exposure_auto=1
Nu er værdi sat til manuel!
Kør:
v4l2-ctl -d 2 -L
Se værdi for exposure_auto. Den vil være 1 for manuel
Kør :
ffmpeg -y -f v4l2 -input_format mjpeg -r 30 -i /dev/video2 -f alsa -thread_queue_size 1024 -i hw:2 -c copy test.mkv
Nu er fps lig 30 fra starten uanset lysstyrke!

Synkroniser lyd. Optag og brug klaptræ. Noter synkronisering fejl. Fx er lyd 1 sekund bagefter. Kør:
ffplay -i stream/`ls stream | tail -n 1`
Ret synkroniseringsfejl. Kør:
ffmpeg -y -i stream/`ls stream | tail -n 1` -itsoffset -1 -i stream/`ls stream | tail -n 1` -filter_complex "[0:v:0]null[video];[1:a]anull[audio]" -map [video] -map [audio] -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -c:a aac -b:a 128k -ar 44100 -strict -2 test.mkv
Test synkronisering:
ffplay -i test.mkv
Tilret synkronisering hvis nødvendigt. Brug fx 0.9 s, som i -itsoffset -0.9


ffmpeg -y -i stream/`ls stream | tail -n 1` -itsoffset -0 -i stream/`ls stream | tail -n 1` -filter_complex "[0:v:0]null[video];[1:a]anull[audio]" -map [video] -map [audi -pix_fmt yuvj420p -c:v mjpeg -q:v 1 -c:a aac -b:a 128k -ar 44100 -strict -2 test.mkv

Søg binært:
xxd -p playbackFiller/25.mjpeg | tr -d '\n' | grep -o 'ffd9' | less -N

Hent tilpasset verison af ffplay til github lokal folder:
cp ~/ffmpeg_sources/ffmpeg/fftools/ffplay.c ~/github/easystream

Web Cam Applet Control:
qv4l2
