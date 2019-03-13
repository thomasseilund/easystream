// From http://tldp.org/HOWTO/Serial-Programming-HOWTO/x115.html#AEN129

/*

Thomas Seilund, tps@netmaster.dk

jan. 2009.

This program creates or reads a data file with specifications for a text that is inserted into a
video stream handled by a modified version of ffmpeg.

Change log
Date	By	Remarks
17/11/9	TPS	Add comments.
5/12/10	TPS	Handle shotclock, 24 sec. clock.
3/1/13	TPS	Simplify. Write values to 6 files. One file for each of the values
	home, guest, minute, second, quarter, shotclock. The files are read by
	ffmpeg filter drawtext.
*/

#include <stdio.h>
#include <errno.h> 	// strerror(errno)
#include <stdlib.h> 	// exit(EXIT_FAILURE);
#include <string.h> 	// strerror(errno)
#include <sys/timeb.h> 	// ftime()
#include <time.h> 	// localtime()
#include <sys/ipc.h>	// ipcget()
#include <sys/shm.h>	// ipcget()
#include <assert.h>
#include <termios.h>
#include <fcntl.h>

#define TENTHOFASECOND 0.1
#define BAUDRATE B57600
#define _POSIX_SOURCE 1 /* POSIX compliant source */
#define FALSE 0
#define TRUE 1

// Map to shared memory
struct nautronic {int home, guest, minute, second, quarter, shotclock;};
struct nautronic *scoreboard = NULL;

struct termios oldtio,newtio;	// port settings

FILE *input = 0, *output = NULL;

enum states {
	SYSTEMADDRESS0A		// received command for all scoreboards
	, PACKETTIMESTARTSTOP	// received subcommand for gametime packet
	, PACKETTIME		// received subcommand for gametime packet
	, PACKETHOMESCORE	//                         home score packet
	, PACKETAWAYSCORE	//                         away score packet
	, PACKETPERIOD		//                         period
	, PACKETSUBMINUTE	//                         subminute - less than one minute left, show 1/10 sec.
	, PACKETSHOTCLOCK	//			   shotclock - 24 sec. clock.
	, ENDOFPACKET		// received end of packet
	, PACKETUNKNOWN		// received packet we don't handle
	};
int currentstate = ENDOFPACKET;		// current state of reading the clock

int home = 0, guest = 0, minute = 0, second = 0, quarter = 0, shotclock = 0;

int databyte;			// data byte number of current packet

int shmid;			// id for shared memory - shmget()
FILE *fp = NULL;

int subminute;			// 1 if less than one minute left else 0

int timeRunning;		// 0: false. 1: true.
//int fd,i,rc,rcRead;
int rcRead;
int fd; 

unsigned char c;		// char read
unsigned char gametime[4],hs[2],as[2],sc[2];	// packet information. gametime, home score, away score, shotclock

// Helpers for getting time (with milliseconds) and pausing
struct timeb ts1;	// time with milliseconds
struct tm *ts2;		// time broken into components, not including milliseconds
struct timespec delay;	// specify a delay

struct timeval tvLastPacketTime;// var for sub-second work!

void error(char *file, char *text)
{
	char *err;
	asprintf(&err, "%s. %s.", file, text); 
	perror(err);
}

void writeboardToSharedMem()
{
	// Init only once!
	static int lhome = -1, lguest = -1, lminute = -1, lsecond = -1, lquarter = -1, lshotclock = -1;

	// If value has changed then update value in shared memory
	if (lhome != home) {lhome = scoreboard->home = home;}
	if (lguest != guest) {lguest = scoreboard->guest = guest;}
	if (lminute != minute) {lminute = scoreboard->minute = minute;}
	if (lsecond != second) {lsecond = scoreboard->second = second;}
	if (lquarter != quarter) {lquarter = scoreboard->quarter = quarter;}
	if (lshotclock != shotclock) {lshotclock = scoreboard->shotclock = shotclock;}

	// Print to stdout. 
	printf("Q%d H: %02d G: %02d %02d:%02d %02d\n",quarter, home, guest, minute, second, shotclock);
}

// Convert the characters we have collected for each packet to an integer value
void convertScoreboardBytesToInt()
{
	minute = ((gametime[0] & 0x0f) % 0x0f) * 10 + (gametime[1] & 0x0f) % 0x0f;
	second = ((gametime[2] & 0x0f) % 0x0f) * 10 + (gametime[3] & 0x0f) % 0x0f;
	home = hs[0] / 0x20 * 100 + ((hs[0] & 0x0f) % 0x0f * 10) + (hs[1] & 0x0f);
	guest = (as[0] / 0x20 * 100) + ((as[0] & 0x0f) % 0x0f * 10) + (as[1] & 0x0f);
	shotclock = ((sc[0] & 0x0f) % 0x0f) * 10 + (sc[1] & 0x0f) % 0x0f;
}

main(int argc, char * argv[])
{
	// Print help
	printf("Call: %s inputfile outputfile\n", argv[0]);
	printf("Ie. : %s /dev/usbX nautronic.dat \n", argv[0]);
	printf("\n");

	// Create shared memory
	if ((shmid = shmget(IPC_PRIVATE, sizeof(struct nautronic), IPC_CREAT | 0666)) == -1)
	{
		perror("shmget");
		exit(-1);
	}

	// Save id of shared memory
	if ((fp = fopen("shmid", "w")) == NULL)
	{
		perror("open file shmid");
		exit(-1);
	}
	if (fprintf(fp, "%d", shmid) < 0)
	{
		perror("write to file shmid");
		exit(-1);
	}
	if (fclose(fp) != 0)
	{
		perror("close file shmid");
		exit(-1);
	}

	// Attach to shared memory
	if ((scoreboard = shmat(shmid, NULL, 0)) == (void *) -1)
	{
		perror("attach to shared memory");
		exit(-1);
	}
	
	printf("shmget. shmid: %d\n", shmid);





	// Open input file.
	fd = open(argv[1], O_RDONLY | O_NOCTTY ); 
	//if (fd <0) {perror(argv[1]); exit(EXIT_FAILURE); }	// quit if error
	if (fd < 0) {perror(argv[1]);}	// quit if error
	
	// save current port settings
	tcgetattr(fd,&oldtio); 
	bzero(&newtio, sizeof(newtio));
	newtio.c_cflag = BAUDRATE | CRTSCTS | CS8 | CLOCAL | CREAD | PARENB | CMSPAR | PARODD; // 8M1
	newtio.c_iflag = IGNPAR;
	newtio.c_oflag = 0;
	
	/* set input mode (non-canonical, no echo,...) */
	newtio.c_lflag = 0;
	 
	// tps timeout = 0.1 sec - see http://www.cygwin.com/ml/cygwin-developers/2002-08/msg00154.html
	newtio.c_cc[VTIME]		= 1;	 /* inter-character timer unused */
	// tps : http://www.steve.org.uk/Reference/Unix/faq_4.html
	newtio.c_cc[VMIN]		= 0;	 /* blocking read until 1 char received */
	
	tcflush(fd, TCIFLUSH);
	tcsetattr(fd,TCSANOW,&newtio);
		
	currentstate = ENDOFPACKET; // read state.













	// Open input file
	if (fd < 0) 
	{
		// No game clock input file. Not as device and not as regular file. Show current time in score board.
		printf("%s. %s. Could not open. Use current time as input.\n", argv[0], argv[1]); 

		while (1)
		{
			// Get structure with time and milliseconds
			ftime(&ts1);
			ts2 = localtime(&ts1.time);

			home = ts2->tm_min;
			guest = ts2->tm_sec;
			second = ts1.millitm / 10;

                        writeboardToSharedMem();

                        delay.tv_sec = 0;
                        delay.tv_nsec = 10000000;
                        nanosleep(&delay, NULL);
		}
	}



	// Input file opened successfully
	//while ((rcRead = fgetc(input)) != EOF )
	//while ((rcRead = read(fileno(input), &c, 1)) > -1)
	while ((rcRead = read(fd, &c, 1)) > -1)
	{
		// Debug info
		//if ((debug) && (rcRead > 0))
		if (rcRead > 0)
		{
			printf("%02Xh\t", c); 
			if ((c >= 0x80) && (currentstate != PACKETTIME)) printf("\n");
		}

		// Are we handling a packet and have we received an end of packet?		
		if ((currentstate != ENDOFPACKET) && (c >= 0x80)) 
		{
			// Yes, we are at the end of a packet that we handle.

			// Does this packet change the scoreboard?
                        if (
                        	(currentstate == PACKETTIME)
			) 
			{
				// Yes, print scoreboard.

	                        // Make a note of what time we print clock, so we can calculate
        	                // when 1/10 sec. changes.
                	        gettimeofday(&tvLastPacketTime, NULL);

				convertScoreboardBytesToInt();
				writeboardToSharedMem();
			}

			// Set end of packet and zero out received packet data.
                        currentstate = ENDOFPACKET;
                        databyte = 0;
		}
		else if ((currentstate == ENDOFPACKET) && (c == 0x0a)) currentstate = SYSTEMADDRESS0A; 
		else if (currentstate == SYSTEMADDRESS0A)
		{
			if      (c == 0x00) currentstate = PACKETHOMESCORE;
			else if (c == 0x02) currentstate = PACKETPERIOD;
			else if (c == 0x03) currentstate = PACKETAWAYSCORE;
			else if (c == 0x30) currentstate = PACKETTIMESTARTSTOP;
			else if (c == 0x0c) currentstate = PACKETTIME;
			else if (c == 0x41) currentstate = PACKETSUBMINUTE;
			else if (c == 0x12) currentstate = PACKETSHOTCLOCK;
			else currentstate = PACKETUNKNOWN;  // packets we don't handle
		} 
                else if (currentstate == PACKETPERIOD) quarter = c;
                else if (currentstate == PACKETSHOTCLOCK) {assert(databyte < 2); sc[databyte++] = c;}
                else if (currentstate == PACKETHOMESCORE) {assert(databyte < 2); hs[databyte++] = c;}
		else if (currentstate == PACKETAWAYSCORE) {assert(databyte < 2); as[databyte++] = c;}
		else if (currentstate == PACKETTIME) {assert(databyte < 4); gametime[databyte++] = c;}
		else if (currentstate == PACKETTIMESTARTSTOP) {if (c == 0x20) timeRunning = 1; if (c == 0x40) timeRunning = 0;}
		// If time is not running, ie. during timeout, we might get a !subminute.
		else if (currentstate == PACKETSUBMINUTE) {if (timeRunning) subminute = (c == 0x4E);}

       	} // End of while loop

	fclose(input);
}
