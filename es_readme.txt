mkdir newdir
cd newdir
PATH=$PATH:~/data/data/git/easystream
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

Terminal 1:

Test kamera, fx /dev/video2 Størrelse på video sættes senere

ffplay -i /dev/video2

Terminal 2:

Fokuser. Kun nødvendigt når der ikke er fokusering på kampera. Det er der typisk ikke på webcams

es_fokus -v 2

Terminal 1:

Optag - speed skal komme op på 1

es2_capture.sh -t UVC -n 1 -v 2 -s hd720 -r 24 -a 1 -b

Terminal 2:

Gør klar til at stoppe/starte lydoptagelse. Stop evt. optagelse af lyd til kamp starter

es_on_off.sh 

Terminal 3:

Se live optagelse. Forvent lavere kvalitet. Streaming-kvalitet er højere

es_play_stream_from_udp.sh -n 1

Terminal 4:

Live stream til YouTube. X1 is YouTube user. Y2 is YouTube Stream name/key. Speed skal komme op på 1.
Gå til din kanal på YouTube og derefter https://www.youtube.com/features
Vælg "LIVE STREAMING" og find det "Stream name/key"

es_stream_to_youtube.sh  -n 1 -U X1 -Y X2

Når du har udført kommando ovenfor, så streames til YouTube.

Gå til din kanal på YouTube og check at stream er ok. Optag evt. lyd, hvis du tidligere slog lyd fra



