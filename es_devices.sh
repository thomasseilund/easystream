#bin/bash

echo ALSA
echo ====
arecord -l
echo

echo V4L2 devices
echo ============
v4l2-ctl --list-devices

echo V4L2 devices frame size and fps
echo ===============================
# v4l2-ctl --list-formats-ext
for i in /dev/video*; do echo $i ; `echo v4l2-ctl --list-formats-ext -d $i`; done
