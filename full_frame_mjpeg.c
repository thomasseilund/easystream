#include <stdio.h>
#include <unistd.h>             /* for getopt */

/*
Copy mjpeg frames from stdin to stdout
Start copy at frame break, ie. SOI - start of image
*/

int flag_verbose;

static void usage(void)
{
  fprintf(stderr, "Write full frames to stdout\n");
  fprintf(stderr, "Don't write starting or ending incomplete frames\n");
  fprintf(stderr, "usage: full_frame_mjpeg [OPTIONS]\n");
  fprintf(stderr, "\n"
         "Options:\n"
         "-v                verbose output\n"
         "-h                print this help\n");
}

int main(int argc, char *argv[])
{
	FILE *fp = tmpfile();
	int c, ch, ch_last, start_of_image, end_of_image, chars, used_chars;
	c=ch=ch_last=start_of_image=end_of_image=chars=used_chars=0;

	/* Get command line options */
  while ((c = getopt(argc, argv, "hv")) != -1) {
      switch (c) {
        case 'v':
          flag_verbose = 1;
          break;
	      case 'h':
	          usage();
	          return 0;
	      case '?':
	          return 1;
      }
  }

	while ((ch = fgetc(stdin)) != EOF)
	{
    chars++;
    if (flag_verbose)
		  fprintf(stderr, "SOI: %i\tEOI: %i\tchars: %i\tused chars: %i\n"
      ,start_of_image
      ,end_of_image
      ,chars
      ,used_chars);
    if (ch_last == 255 && ch == 216) /* 0xFF D8 */
		{
      start_of_image++;
		}
		if (start_of_image > 0)
    {
      used_chars++;
			fputc(ch, fp); //stdout);
    }
    if (ch_last == 255 && ch == 217) /* 0xFF D9 */
    {
      end_of_image++;
			rewind(fp);
			while ((ch = fgetc(fp)) != EOF)
				putchar(ch);
      fclose(fp);
			fp = tmpfile();
		}
		ch_last = ch;
	}
	return 0;
}
