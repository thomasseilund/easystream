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
#define NO_PLAY_BACK_FILE_25  "playbackFiller/25.mjpeg"
#define NO_PLAY_BACK_FILE_1   "playbackFiller/1.mjpeg"
//#define NO_PLAY_BACK_FILE_1   "playbackNo/1.mjpeg"

/* Global varialbles */
//int calls;
const char *bind_address = "tcp://127.0.0.1:5555";
unsigned long epoch; /* */
//unsigned long streamed_until;
const char *overlay_number;
int overlay_x; /* current value for overlay. If overlay_x = 0 then we playback */
int frames_total;
ulong start_milliseconds_since_epoch;
int overlay_delay_milliseconds;
int logline;
int flag_quiet;
char *single_filler_frame;

/* Get number of seconds since epoch */
static unsigned long get_epoch()
{
  return (unsigned long)time(NULL);
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

// /* Peek at and return next character from open file pointer */
// int fpeek(FILE *fp)
// {
//   int c;
//   c = fgetc(fp);
//   ungetc(c, fp);
//   return c;
// }

/* Activate/deactivate overlay by setting x value for overlay */
static int overlay(int x)
{
  int recv_buf_size, ret = 0;
  void *zmq_ctx, *socket;
  zmq_msg_t msg;
  char src_buf[254];
  char recv_buf[254];

  /* Global var indicates if we do playback or not */
  overlay_x = x;

  /* Simulate now overlay */
  if (overlay_number == NULL)
  {
    fprintf(stderr, "Intention: set overlay: %i\n", x);
    return 1;
  }

  if (!flag_quiet)
    fprintf(stderr, "Create ZMQ context\n");
  zmq_ctx = zmq_ctx_new();
  if (!zmq_ctx) {
      fprintf(stderr, "Could not create ZMQ context: %s\n", zmq_strerror(errno));
      return 1;
  }

  if (!flag_quiet)
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

  if (!flag_quiet)
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
  if (!flag_quiet)
    fprintf(stderr, "%s\n", src_buf);

  return 0;
}

/*
Write frames to stdout and return number of frames.
Sleep if needed so we dont write more frames that needed for live playback.
If delay >= 0 then we handle playback otherwise handle filler.
*/
static int write_frames_from_open_file(FILE *fp, const char *filename, int delay)
{
  int ch, ch_last, start_of_image, end_of_image, frames_expected, milliseconds_since_start;
  unsigned long chars;
  char timestamp[100];
  start_of_image = end_of_image = chars = 0;
  while ((ch = fgetc(fp)) != EOF)
  {
    fprintf(stdout, "%c", ch);

    // chars++;
    // fprintf(stderr, "%i,", (int)ch);
    // if ((chars % 40) == 0)
    //   fprintf(stderr, "\n");

    if (ch_last == 255)
    {
      if (ch == 216) /* SOI 0xFF D8 */
        start_of_image++;
      else if (ch == 217) /* EOI 0xFF D9 */
      {
        end_of_image++;
        frames_total++;

        // /* Take delay of overlay activation into accout? */
        // if (delay >= 0)
        // {
        //   /* Yes. */
        //   if (overlay_x != 0 && end_of_image * 40 > delay)
        //     overlay(0);
        // }

        milliseconds_since_start = get_milliseconds_since_epoch() - start_milliseconds_since_epoch;
        frames_expected = milliseconds_since_start / 40;

        /* Debug statement */
        if (!flag_quiet && (frames_total % 5) == 0)
        {
          // if ((chars % 40) != 0)
          //   fprintf(stderr, "\n");
          fprintf(stderr, "%s %s SOI: %4i EOI: %4i FPS: %.2f F written:%5i F expected: %5i ms: %6i Logline: %5i\n"
            ,get_timestamp(timestamp)
            ,filename
            ,start_of_image
            ,end_of_image
            ,(float) frames_total / milliseconds_since_start * 1000   /* FPS */
            ,frames_total                                   /* Frames written */
            ,milliseconds_since_start / 40                  /* Frames expected */
            ,milliseconds_since_start
            ,logline++);
        }

        /* Wait? */
        if (frames_total > frames_expected)
        {
          usleep((frames_total - frames_expected) * 40 * 1000); /* milliseconds */
          //fprintf(stderr, "usleep(): %i\ttotal: %i\texpected: %i\n", 40000, frames_total, frames_expected);
        }
      } // end of image
    } // if (ch_last == 255)
    ch_last = ch;
  } // while ((ch = fgetc(fp)) != EOF)
  if (overlay_x == 0)
  {
    /* Take delay of overlay deactivation into accout? */
    if (delay >= 0)
      usleep(delay * 1000);
    overlay(9999); /* stop show overlay,playback */
  }
  return start_of_image;
}

/* Write frames to stdout and return number of frames */
static int write_frames(const char *filename)
{
  //fprintf(stderr, "1. static int write_frames(const char *filename)\n");
  FILE *fp;
  int frames;
  if ((fp = fopen(filename, "r")) == NULL)
  {
    fprintf(stderr, "Error opening file %s: %s\n", filename, strerror( errno ));
    return 0;
  }
  frames = write_frames_from_open_file(fp, filename, -1);
  fclose(fp);
  //fprintf(stderr, "2. static int write_frames(const char *filename)\n");
  return frames;
}

// static int get_frames(const char *filename)
// {
//   FILE *fp;
//   char cmd[254];
//   int frames = -1;
//
//   sprintf(cmd, "ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 %s", filename);
//
//   if ((fp = popen(cmd, "r")) == NULL)
//   {
//     fprintf(stderr, "Error running command %s: %s\n", cmd, strerror( errno ));
//   }
//   else
//   {
//     fscanf(fp, "%i", &frames);
//     fclose(fp);
//   }
//   return frames;
// }

/* DoStuff */
static void DoStuff(void)
{
  /* Do we have playback? */
  int frames, frames_single;
  FILE *fp;
  char timestamp[100];
  long l;
  if ((fp = fopen(PLAY_BACK_FILE, "r")) != NULL)
  {
    /* Yes, we do have playback */
    /* Rename playback file so new playback file can be placed in playback folder */
    if (!flag_quiet)
      fprintf(stderr, "%s rename file 1\n", get_timestamp(timestamp));
    rename(PLAY_BACK_FILE, PLAY_BACK_FILE_TEMP);
    /* Playback */
    //overlay(0); /* if we have -re option on ffmpeg command then .. */
    // /* If we tail from a live stream to PLAY_BACK_FILE then we risk that the
    //   file exists but is empty when we start reading from it. Give a little
    //   time for the file to have content! */
    // l = 0;
    // while (l == 0)
    // {
    //   fseek(fp, 0L, SEEK_END);
    //   l = ftell(fp);
    //   if (l == 0)
    //     usleep(80 * 1000); /* milliseconds */
    // }
    // rewind(fp);
    overlay(0);
    frames = write_frames_from_open_file(fp, PLAY_BACK_FILE_TEMP, overlay_delay_milliseconds);
    fclose(fp);
    if (!flag_quiet)
      fprintf(stderr, "%s rename file 2\n", get_timestamp(timestamp));

    // /* Handle sub second frame fillers */
    // frames_single = frames mod 25;
    // if (frames_single != 0)
    // {
    //   if ((fp = fopen(NO_PLAY_BACK_FILE_1, "r")) == NULL)
    //   {
    //     fprintf(stderr, "Error opening file %s: %s\n", NO_PLAY_BACK_FILE_1, strerror( errno ));
    //     return 0;
    //   }
    //   for (int i = 0; i++; i < 25 - frames_single)
    // frames = write_frames_from_open_file(fp, filename, -1);
    // fclose(fp);


  }
  else
  {
    /* No, we have no playback. Use filler image */
    //frames = write_frames(NO_PLAY_BACK_FILE_25);
    frames = write_frames(NO_PLAY_BACK_FILE_1);
    //streamed_until++;
  }
}

// static void readin_single_frame()
// {
//   FILE *f = fopen(NO_PLAY_BACK_FILE_1, "rb");
//   fseek(f, 0, SEEK_END);
//   long fsize = ftell(f);
//   fseek(f, 0, SEEK_SET);  /* same as rewind(f); */
//   single_filler_frame = malloc(fsize + 1);
//   fread(single_filler_frame, 1, fsize, f);
//   fclose(f);
// }


static void usage(void)
{
  fprintf(stderr, "Write frames to stdout\n");
  fprintf(stderr, "Write ./playbackFiller/25.mjpeg repeatedly to stdout\n");
  fprintf(stderr, "If ./playback/playback.mjpeg exists then write that file to stdout\n");
//  fprintf(stderr, "Write ./playbackNo/1.mjpeg repeatedly to stdout until one full second is reached\n");
  fprintf(stderr, "Go back and write ./playbackNo/25.mjpeg repeatedly to stdout\n");
  fprintf(stderr, "usage: es_write_frames [OPTIONS]\n");
  fprintf(stderr, "\n"
         "Options:\n"
         "-b ADDRESS        set bind address. Default tcp://127.0.0.1:5555\n"
         "-h                print this help\n"
  //       "-f                background frame, 1 sec\n"
  //       "-F                background frame 1/25 sec\n"
         "-o                overlay number. See ffmpeg report output. If not specified then no overlay handling\n"
         "-d                if playback shows n red frames before playback then compensate by option -d n\n"
         "-q                quiet\n"
         "-i INFILE         set INFILE as input file, stdin if omitted\n");
}

int main(int argc, char *argv[]) {
  /* Get command line options */
  int c;
  while ((c = getopt(argc, argv, "hf:F:o:b:d:q")) != -1) {
      switch (c) {
        case 'b':
          bind_address = optarg;
          break;
        case 'q':
          flag_quiet = 1;
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
        case 'd':
            overlay_delay_milliseconds = atoi(optarg);
            break;
        case '?':
            return 1;
      }
  }

  // /* Set up timer */
  // struct itimerval it_val;      /* for setting itimer */
  //
  // /* Upon SIGALRM, call DoStuff().
  //  * Set interval timer.  We want frequency in ms,
  //  * but the setitimer call needs seconds and useconds. */
  // if (signal(SIGALRM, (void (*)(int)) DoStuff) == SIG_ERR) {
  //   perror("Unable to catch SIGALRM");
  //   exit(1);
  // }
  // it_val.it_value.tv_sec =     INTERVAL/1000;
  // it_val.it_value.tv_usec =    (INTERVAL*1000) % 1000000;
  // it_val.it_interval = it_val.it_value;
  // if (setitimer(ITIMER_REAL, &it_val, NULL) == -1) {
  //   perror("error calling setitimer()");
  //   exit(1);
  // }

  /*
  Don't risk that this playback frame pump pipes frames to ffmpeg
  before ffmpeg picks up frames from cameras on physical devices
  */
  if (!flag_quiet)
    fprintf(stderr, "Sleep 2 secs to allow ffmpeg to capture from devices\n");
  usleep(overlay_delay_milliseconds * 40 * 1000);


  // epoch = streamed_until = get_epoch();
  epoch = get_epoch();
  overlay_x = 9999; /* don't show overlay/playback */
  start_milliseconds_since_epoch = get_milliseconds_since_epoch();

  while (1)
    DoStuff();
}
