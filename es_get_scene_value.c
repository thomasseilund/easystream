#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#define FRAME_SPAN 25
#define MOTION_THRESHOLD 1
const char *starts_with = "[Parsed_select_0";

int main()
{
  char *buffer;
  size_t bufsize = 254;
  size_t characters;
  char *token;
  char delim[] = " :";
  int frame = 0;
  float scenes[FRAME_SPAN];
  int i;
  float scenes_sum = 0;
  float scene = 0;
  int motion = 0;

  buffer = (char *)malloc(bufsize * sizeof(char));
  for (i = 0; i < FRAME_SPAN; i++)
    scenes[i] = -1;

  // read stdin forever
  do
  {
    // exit loop if no more stdin
    if (getline(&buffer, &bufsize, stdin) == -1)
      exit;
    // care only about stdin lines that start with 'starts_with'
    if (strncmp(buffer, starts_with, strlen(starts_with)) == 0)
    {
      //fprintf(stdout, "%s", buffer);
      // split stdin into tokens and look for token 'scene'
      token = strtok(buffer, delim);
      while (token != NULL)
      {
        if (strcmp(token, "scene") == 0)
        {
          // get token after token 'scene'. That is the motion value
          token = strtok(NULL, delim);
          // store motion value in array with index i
          i = frame % FRAME_SPAN;
          if (scenes_sum > MOTION_THRESHOLD)
            motion = 1;
          else
            motion = 0;

          if (scenes[i] != -1)
            scenes_sum -= scenes[i];
          scenes[i] = scene = atof(token);
          scenes_sum += scene;

          // Debug information
          //for (i = 0; i < FRAME_SPAN; i++) fprintf(stdout, "%f\n", scenes[i]);
          fprintf(stdout, "%i\t%f\t%f\n", frame, scene, scenes_sum / FRAME_SPAN);
          //fprintf(stdout, "%i\t%s\n", frame, token);
          frame++;
          exit;
        }
        token = strtok(NULL, delim);
      }
    }
  } while (1);
}
