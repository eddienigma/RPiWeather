/*
 * rht.c - Relative Humidity and Temperature
 * Based on code from the wiringPI v2 library.
 * Corrected the temperature reading function to properly handle negative temperatures.
 *
 * This program pulls the current temp and humidity from a DHT22 / SM2302 sensor
 * once and then exits. The data is printed out on a single line in the format
 * Unix time stamp, temp in Celsius, temp in Fahrenheit, Relative humidity
 * This is intended to make it easy to parse by other programs.
 *
 * Copyright 2014 by Jason Seymour
 * Version 1.0
 * Revision 1.0
*/

#include <stdio.h>
#include <stdlib.h>
#include <wiringPi.h>
#include <time.h>

#define RHT03_PIN       7

#ifndef TRUE
#  define       TRUE    (1==1)
#  define       FALSE   (1==2)
#endif


/* ********************************************************
 * maxDetectLowHighWait:
 *      Wait for a transition from high to low on the bus
 **********************************************************
*/

static void maxDetectLowHighWait (const int pin)
{
  unsigned int timeOut = millis () + 2000 ;

  while (digitalRead (pin) == HIGH)
    if (millis () > timeOut)
      return ;

  while (digitalRead (pin) == LOW)
    if (millis () > timeOut)
      return ;
}

/* ****************************************************
 * maxDetectClockByte:
 *      Read in a single byte from the MaxDetect bus
 ******************************************************
*/

static unsigned int maxDetectClockByte (const int pin)
{
  unsigned int byte = 0 ;
  int bit ;

  for (bit = 0 ; bit < 8 ; ++bit)
  {
    maxDetectLowHighWait (pin) ;

// bit starting now - we need to time it.

    delayMicroseconds (30) ;
    byte <<= 1 ;
    if (digitalRead (pin) == HIGH)      // It's a 1
      byte |= 1 ;
  }

  return byte ;
}


/* *******************************************************************************
 * maxDetectRead:
 *      Read in and return the 4 data bytes from the MaxDetect sensor.
 *      Return TRUE/FALSE depending on the checksum validity
 *********************************************************************************
*/

int maxDetectRead (const int pin, unsigned char buffer [4])
{
  int i ;
  unsigned int checksum ;
  unsigned char localBuf [5] ;

// Wake up the RHT03 by pulling the data line low, then high
//      Low for 10mS, high for 40uS.

  pinMode      (pin, OUTPUT) ;
  digitalWrite (pin, 0) ; delay             (10) ;
  digitalWrite (pin, 1) ; delayMicroseconds (40) ;
  pinMode      (pin, INPUT) ;

// Now wait for sensor to pull pin low

  maxDetectLowHighWait (pin) ;

// and read in 5 bytes (40 bits)

  for (i = 0 ; i < 5 ; ++i)
    localBuf [i] = maxDetectClockByte (pin) ;

  checksum = 0 ;
  for (i = 0 ; i < 4 ; ++i)
  {
    buffer [i] = localBuf [i] ;
    checksum += localBuf [i] ;
  }
  checksum &= 0xFF ;

  return checksum == localBuf [4] ;
}

/* ************************************************************
 * readRHT03:
 *      Read the Temperature & Humidity from an RHT03 sensor
 **************************************************************
*/

int readRHT03 (const int pin, int *temp, int *rh)
{
  static unsigned int nextTime   = 0 ;
  static          int lastTemp   = 0 ;
  static          int lastRh     = 0 ;
  static          int lastResult = TRUE ;

  unsigned char buffer [4] ;

// Don't read more than once a second


  if (millis () < nextTime)
  {
    *temp = lastTemp ;
    *rh   = lastRh ;
    return lastResult ;
  }

  lastResult = maxDetectRead (pin, buffer) ;

  if (lastResult)
  {
    lastTemp = buffer [2] & 0x7F;
    lastTemp *= 256;
    lastTemp += buffer [3];
    if (buffer [2] & 0x80)
    {
	lastTemp *= -1;
    }
    *temp = lastTemp;
    *rh        = lastRh     = (buffer [0] * 256 + buffer [1]) ;
    nextTime   = millis () + 2000 ;
    return TRUE ;
  }
  else
  {
    return FALSE ;
  }
}


/*
 ***********************************************************************
 * The main program
 ***********************************************************************
 */

int main ()
{
  int temp = 0;
  int rh = 0;
  unsigned int curTime = 0;
  float tempC = 0.0;
  float tempF = 0.0;
  float rhFloat = 0.0;


  wiringPiSetup () ;
  piHiPri       (55) ;

  readRHT03(RHT03_PIN, &temp, &rh);
  tempC = temp / 10.0;
  tempF = ((tempC * 9) /  5) + 32;
  rhFloat = rh / 10.0;
  curTime = time(NULL);
  printf("%i,%3.2f,%3.2f,%2.2f\n", curTime, tempC, tempF, rhFloat);

  exit(0);
}




