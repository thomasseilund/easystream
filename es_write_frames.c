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

#define INTERVAL 1000           /* number of milliseconds to go off */
#define BUFSIZE 4096            /* buffered read from files */
#define STDOUT 1                /* file number for stdout */
#define PLAY_BACK_FILE        "playback/playback.mjpeg"
#define PLAY_BACK_FILE_TEMP   "playback/playback.mjpeg_temp"
#define NO_PLAY_BACK_FILE_25  "playbackNo/25.mjpeg"
#define NO_PLAY_BACK_FILE_1   "playbackNo/1.mjpeg"

/* Global varialbles */
int calls;

const char *bind_address = "tcp://localhost:5555";
// const char *in_filename_frame_1000_msec = NULL; /* frame 1 sec */
// const char *in_filename_frame_0400_msec = NULL; /* frame 1/25 sec */
unsigned long epoch; /* */
unsigned long streamed_until;


static unsigned long get_epoch()
{
  return (unsigned long)time(NULL);
}

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

static void write_frames_from_open_file(FILE *fp, const char *filename)
{
  int ch;
  fprintf(stderr, "%s\n", filename);
  while ((ch = fgetc(fp)) != EOF)
    fprintf(stdout, "%c", ch);
}

static void write_frames(const char *filename)
{
  FILE *fp;
  if ((fp = fopen(filename, "r")) == NULL)
  {
    fprintf(stderr, "Error opening file %s: %s\n", filename, strerror( errno ));
    return;
  }
  write_frames_from_open_file(fp, filename);
  fclose(fp);
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
 * DoStuff
 */
static void DoStuff(void)
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
      write_frames_from_open_file(fp, PLAY_BACK_FILE_TEMP);
      fclose(fp);
      /* Get number of frames in playback */
      int frames = get_frames(PLAY_BACK_FILE_TEMP);
      /* Get numbers of full seconds of playback */
      int seconds_full = frames / 25;
      /* Get numbers of second fractions, 1/25, of playback */
      int seconds_fraction = frames % 25;
      /* Stream so we are on the one second boundary */
      for (int i = 0; i < seconds_fraction; i++)
        write_frames(NO_PLAY_BACK_FILE_1);
      /* Increase how long we have streamed */
      streamed_until += seconds_full;
      if (seconds_fraction > 0)
        streamed_until++;
      fprintf(stderr, "%s\tframes %i\tsec. %i\tsec fraction %i\n"
      ,PLAY_BACK_FILE
      ,frames
      ,seconds_full
      ,seconds_fraction);
    }
    else
    {
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
  printf("Send frames to stdout\n");
  printf("usage: es_write_frames [OPTIONS]\n");
  printf("\n"
         "Options:\n"
         "-b ADDRESS        set bind address\n"
         "-h                print this help\n"
         "-f                background frame, 1 sec\n"
         "-F                background frame 1/25 sec\n"
         "-i INFILE         set INFILE as input file, stdin if omitted\n");
}

int main(int argc, char *argv[]) {
  /* Get command line options */
  int c;
  while ((c = getopt(argc, argv, "hf:F:")) != -1) {
      switch (c) {
      case 'h':
          usage();
          return 0;
      // case 'f':
      //     in_filename_frame_1000_msec = optarg;
      //     break;
      // case 'F':
      //     in_filename_frame_1000_msec = optarg;
      //     break;
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

  /*
    Call pause repeatedly. For each call we wait for timer to elapse-
    When timer epases we call DoStuff()
    */
  while (1)
    pause();
}
