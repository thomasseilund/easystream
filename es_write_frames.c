  /*
 * setitimer.c - simple use of the interval timer
 */

#include <sys/time.h>           /* for setitimer */
#include <unistd.h>             /* for pause */
#include <signal.h>             /* for signal */
#include <stdio.h>              /* for printf */
#include <stdlib.h>             /* for exit */
#include <sys/timeb.h>          /* for timeb */
#include <time.h>               /* for strftime */
#include <string.h>             /* for string */
#include <fcntl.h>              /* for open */
#include <errno.h>              /* for errno */
#include <zmq.h>

#define INTERVAL 1000           /* number of milliseconds to go off */
#define BUFSIZE 4096            /* buffered read from files */
#define STDOUT 1                /* file number for stdout */
#define PLAY_BACK_FILE        "playback/playback.mjpeg"
#define PLAY_BACK_FILE_TEMP   "playback/playback.mjpeg_temp"
#define NO_PLAY_BACK_FILE_25  "playbackNo/25.mjpeg"
#define NO_PLAY_BACK_FILE_1   "playbackNo/1.mjpeg"

/* Global varialbles */
int calls;
const char *bind_address = "tcp://127.0.0.1:5555";
unsigned long epoch; /* */
unsigned long streamed_until;
const char *overlay_number;
int overlay_x; /* current value for overlay. If overlay_x = 0 then we playback */
int frames_total;
ulong start_milliseconds_since_epoch;

/* Get number of seconds since epoch */
static unsigned long get_epoch()
{
  return (unsigned long)time(NULL);
}

/* Write timestamp with milliseconds to buf and return buf */
static char* get_timestamp(char* buf)
{
  struct timeb start;
  char append[100];
  if (buf)
  {
    ftime(&start);
    strftime(buf, 100, "%H:%M:%S", localtime(&start.time));
    sprintf(append, ":%03u", start.millitm); // append milliseconds
    strcat(buf, append);
  }
  return buf;
}

/* Get number of milliseconds since epoch */
static ulong get_milliseconds_since_epoch()
{
  ulong res;
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return (unsigned long long)(tv.tv_sec) * 1000 +
      (unsigned long long)(tv.tv_usec) / 1000;
}

/* Peek at and return next character from open file pointer */
int fpeek(FILE *fp)
{
  int c;
  c = fgetc(fp);
  ungetc(c, fp);
  return c;
}

/*
Write frames to stdout and return number of frames.
Sleep if needed so we dont write more frames that needed for live playback.
*/
static int write_frames_from_open_file(FILE *fp, const char *filename)
{
  int ch, ch_last, start_of_image, end_of_image, frames_expected;
  unsigned long epoch_now; /* */
  char timestamp[100];
  while ((ch = fgetc(fp)) != EOF)
  {
    if (ch_last == 255 && ch == 216)
      start_of_image++;
    if (ch_last == 255 && ch == 217)
    {
      end_of_image++;
      frames_total++;
      /* Wait? */
//      if (fpeek(fp) != EOF)
      {
        frames_expected = (get_milliseconds_since_epoch() - start_milliseconds_since_epoch) / 40;
        if (frames_total > frames_expected)
        {
          usleep((frames_total - frames_expected) * 40 * 1000); /* milliseconds */
          //fprintf(stderr, "usleep(): %i\ttotal: %i\texpected: %i\n", microseconds, frames_total, frames_expected);
        }
      }
    }
    fprintf(stdout, "%c", ch);
    ch_last = ch;
    //fprintf(stderr, "%i\n", (int)ch);
  }
  epoch_now = get_epoch();
  fprintf(stderr, "%s\t%s\tSOI: %i\tEOI: %i\tFPS: %f\tFrames written:%i\tFrames expected: %i\n"
    ,get_timestamp(timestamp)
    ,filename
    ,start_of_image
    ,end_of_image
    ,(float) frames_total / (epoch_now - epoch)
    ,frames_total
    ,frames_expected);
  return start_of_image;
}

/* Write frames to stdout and return number of frames */
static int write_frames(const char *filename)
{
  FILE *fp;
  int frames;
  if ((fp = fopen(filename, "r")) == NULL)
  {
    fprintf(stderr, "Error opening file %s: %s\n", filename, strerror( errno ));
    return 0;
  }
  frames = write_frames_from_open_file(fp, filename);
  fclose(fp);
  return frames;
}


static int get_frames(const char *filename)
{
  FILE *fp;
  char cmd[254];
  int frames = -1;

  sprintf(cmd, "ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 %s", filename);

  if ((fp = popen(cmd, "r")) == NULL)
  {
    fprintf(stderr, "Error running command %s: %s\n", cmd, strerror( errno ));
  }
  else
  {
    fscanf(fp, "%i", &frames);
    fclose(fp);
  }
  return frames;
}

/*
Set x value for overlay. This activates or deactivates overlay
depening on x value
*/
static int overlay(int x)
{
  int recv_buf_size, ret = 0;
  void *zmq_ctx, *socket;
  zmq_msg_t msg;
  char src_buf[254];
  char recv_buf[254];

  /* Simulate now overlay */
  // if (strcmp(overlay_number, "-1") == 0)
  // {
  //   return 1;
  // }
  if (overlay_number == NULL)
  {
    return 1;
  }

  overlay_x = x;

  fprintf(stderr, "Create ZMQ context\n");
  zmq_ctx = zmq_ctx_new();
  if (!zmq_ctx) {
      fprintf(stderr, "Could not create ZMQ context: %s\n", zmq_strerror(errno));
      return 1;
  }

  fprintf(stderr, "Create ZMQ socket\n");
  socket = zmq_socket(zmq_ctx, ZMQ_REQ);
  if (!socket) {
      fprintf(stderr, "Could not create ZMQ socket: %s\n", zmq_strerror(errno));
      return 1;
  }

  if (zmq_connect(socket, bind_address) == -1) {
      fprintf(stderr, "Could not bind ZMQ responder to address '%s': %s\n",
             bind_address, zmq_strerror(errno));
      return 1;
  }

  /* Build overlay commando */
  sprintf(src_buf, "Parsed_overlay_%s x %i", overlay_number, overlay_x);

  fprintf(stderr, "Send to socket\n");
  if (zmq_send(socket, src_buf, strlen(src_buf), 0) == -1) {
      fprintf(stderr, "Could not send message: %s\n", zmq_strerror(errno));
      return 1;
  }

  // fprintf(stderr, "Init message\n");
  // if (zmq_msg_init(&msg) == -1) {
  //     fprintf(stderr, "Could not initialize receiving message: %s\n", zmq_strerror(errno));
  //     return 1;
  // }
  //
  // fprintf(stderr, "Receive message\n");
  // if (zmq_msg_recv(&msg, socket, 0) == -1) {
  //     fprintf(stderr, "Could not receive message: %s\n", zmq_strerror(errno));
  //     zmq_msg_close(&msg);
  //     return 1;
  // }
  //
  // recv_buf_size = zmq_msg_size(&msg) + 1;
  // //recv_buf = av_malloc(recv_buf_size);
  // if (!recv_buf) {
  //     fprintf(stderr, "Could not allocate receiving message buffer\n");
  //     zmq_msg_close(&msg);
  //     return 1;
  // }
  //
  // memcpy(recv_buf, zmq_msg_data(&msg), recv_buf_size);
  // recv_buf[recv_buf_size-1] = 0;
  // //printf("%s\n", recv_buf);
  // zmq_msg_close(&msg);
  // //av_free(recv_buf);

  zmq_close(socket);
  zmq_ctx_destroy(zmq_ctx);

  // fprintf(stderr, "%s\t%s\n", src_buf, recv_buf);
  fprintf(stderr, "%s\n", src_buf);

  return 0;
}

/*
 * DoStuff
 */
static void DoStuff(void)
{
  /* Do we have playback? */
  int frames;
  FILE *fp;
  if ((fp = fopen(PLAY_BACK_FILE, "r")) != NULL)
  {
    /* Yes, we do have playback */
    /* Rename playback file so new playback file can be placed in playback folder */
    rename(PLAY_BACK_FILE, PLAY_BACK_FILE_TEMP);
    /* Playback */
    overlay(0); /* if we have -re option on ffmpeg command then .. */
    frames = write_frames_from_open_file(fp, PLAY_BACK_FILE_TEMP);
    fclose(fp);
  }
  else
  {
    /* No, we have no playback. Use filler image */
    if (overlay_x == 0)
      overlay(9999); /* stop show overlay,playback */
    frames = write_frames(NO_PLAY_BACK_FILE_25);
    streamed_until++;
  }
}


/*
 * DoStuff
 */
static void DoStuffOrig(void)
{
  fprintf(stderr, "%lu\n", streamed_until);

  if (streamed_until <= get_epoch())
  {
    /* Do we have playback? */
    FILE *fp;
    if ((fp = fopen(PLAY_BACK_FILE, "r")) != NULL)
    {
      /* Yes, we do have playback */
      /* Rename playback file so new playback file can be placed in playback folder */
      rename(PLAY_BACK_FILE, PLAY_BACK_FILE_TEMP);
      /* Playback */
      overlay(0); /* if we have -re option on ffmpeg command then .. */
      write_frames_from_open_file(fp, PLAY_BACK_FILE_TEMP);
      fclose(fp);
      /* Get number of frames in playback */
      int frames = get_frames(PLAY_BACK_FILE_TEMP);
      /* Get numbers of full seconds of playback */
      int seconds_full = frames / 25;
      /* Get numbers of second fractions, 1/25, of playback */
      int seconds_fraction = frames % 25;
      /* Stream so we are on the one second boundary */
      if (seconds_fraction > 0)
        for (int i = 0; i < 25 - seconds_fraction; i++)
          write_frames(NO_PLAY_BACK_FILE_1);
      /* Increase how long we have streamed */
      streamed_until += seconds_full;
      if (seconds_fraction > 0)
        streamed_until++;
      fprintf(stderr, "%s\tframes %i\tsec. %i\tsec. fraction %i/25\n"
        ,PLAY_BACK_FILE
        ,frames
        ,seconds_full
        ,seconds_fraction);
    }
    else
    {
      /* No, we have no playback. Use filler image */
      if (overlay_x == 0)
        overlay(9999); /* stop show overlay,playback */
      write_frames(NO_PLAY_BACK_FILE_25);
      streamed_until++;
    }
  }


  // char timestamp[100];
  // calls++;
  // int c = calls;
  // printf("A\t%d\t%s\tTimer went off.\n", c, get_timestamp(timestamp));
  // //sleep(1);
  // printf("B\t%d\t%s\n", c, get_timestamp(timestamp));
}

static void usage(void)
{
  fprintf(stderr, "Write frames to stdout\n");
  fprintf(stderr, "Write ./playbackNo/25.mjpeg repeatedly to stdout\n");
  fprintf(stderr, "If ./playback/playback.mjpeg exists then write that file to stdout\n");
  fprintf(stderr, "Write ./playbackNo/1.mjpeg repeatedly to stdout until one full second is reached\n");
  fprintf(stderr, "Go back and write ./playbackNo/25.mjpeg repeatedly to stdout\n");
  fprintf(stderr, "usage: es_write_frames [OPTIONS]\n");
  fprintf(stderr, "\n"
         "Options:\n"
         "-b ADDRESS        set bind address. Default tcp://127.0.0.1:5555\n"
         "-h                print this help\n"
  //       "-f                background frame, 1 sec\n"
  //       "-F                background frame 1/25 sec\n"
         "-o                overlay number. See ffmpeg report output. If not specified then no overlay handling\n"
         "-i INFILE         set INFILE as input file, stdin if omitted\n");
}

int main(int argc, char *argv[]) {
  /* Get command line options */
  int c;
  while ((c = getopt(argc, argv, "hf:F:o:b:")) != -1) {
      switch (c) {
        case 'b':
          bind_address = optarg;
          break;
      case 'h':
          usage();
          return 0;
      // case 'f':overlay_number
      //     in_filename_frame_1000_msec = optarg;
      //     break;
      // case 'F':
      //     in_filename_frame_1000_msec = optarg;
      //     break;
      case 'o':
          overlay_number = optarg;
          // if ((overlay_number = strtol(optarg, NULL, 10)) != 0)
          // {
          //   fprintf(stderr, "Argument -o, '%s', is not a valid overlay numberttt\n", optarg);
          //   usage();
          //   return -1;
          // }
          break;
      case '?':
          return 1;
      }
  }

  /* Set up timer */
  struct itimerval it_val;      /* for setting itimer */

  /* Upon SIGALRM, call DoStuff().
   * Set interval timer.  We want frequency in ms,
   * but the setitimer call needs seconds and useconds. */
  if (signal(SIGALRM, (void (*)(int)) DoStuff) == SIG_ERR) {
    perror("Unable to catch SIGALRM");
    exit(1);
  }
  it_val.it_value.tv_sec =     INTERVAL/1000;
  it_val.it_value.tv_usec =    (INTERVAL*1000) % 1000000;
  it_val.it_interval = it_val.it_value;
  if (setitimer(ITIMER_REAL, &it_val, NULL) == -1) {
    perror("error calling setitimer()");
    exit(1);
  }

  epoch = streamed_until = get_epoch();
  overlay_x = 9999; /* don't show overlay/playback */
  start_milliseconds_since_epoch = get_milliseconds_since_epoch();

  /*
    Call pause repeatedly. For each call we wait for timer to elapse-
    When timer epases we call DoStuff()
    */
  DoStuff();
  while (1)
    pause();
}
