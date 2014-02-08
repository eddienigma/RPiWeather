#!/usr/bin/perl

use RRDp;
use Device::SMBus;
use use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                    clock_gettime clock_getres clock_nanosleep clock
                    stat );

# Instantiate an SMBus object referring to the correct I2C bus
# and the device address of the sensor. The Adafruit BMP180
# sensor always has an address of 0x77. The rev2 RPi puts the
# primary I2C bus on i2c-1. The rev1 uses i2c-0.

my $bmp180 = Device::SMBus->new(
  I2CBusDevicePath => '/dev/i2c-1',
  I2CDeviceAddress => 0x77,
);

# Use this constant to enable or disable printing diagnostic data

use constant DIAG                       => False;

# Define a standard list of operating modes for the sensor.
# These control the number of samples per second that the
# sensor takes internally.

use constant BMP180_ULTRALOWPOWER       => 0;
use constant BMP180_STANDARD            => 1;
use constant BMP180_HIRES               => 2;
use constant BMP180_ULTRAHIRES          => 3;

# Define the sensor registers. Many of these store calibration data
# which is used to calculate temperature compensated pressure readings.

use constant BMP180_CAL_AC1             => 0xAA;        # Calibration data (16 bit)
use constant BMP180_CAL_AC2             => 0xAC;        # Calibration data (16 bit)
use constant BMP180_CAL_AC3             => 0xAE;        # Calibration data (16 bit)
use constant BMP180_CAL_AC4             => 0xB0;        # Calibration data (16 bit)
use constant BMP180_CAL_AC5             => 0xB2;        # Calibration data (16 bit)
use constant BMP180_CAL_AC6             => 0xB4;        # Calibration data (16 bit)
use constant BMP180_CAL_B1              => 0xB6;        # Calibration data (16 bit)
use constant BMP180_CAL_B2              => 0xB8;        # Calibration data (16 bit)
use constant BMP180_CAL_MB              => 0xBA;        # Calibration data (16 bit)
use constant BMP180_CAL_MC              => 0xBC;        # Calibration data (16 bit)
use constant BMP180_CAL_MD              => 0xBE;        # Calibration data (16 bit)
use constant BMP180_CONTROL             => 0xF4;
use constant BMP180_TEMPDATA            => 0xF6;
use constant BMP180_PRESSUREDATA        => 0xF6;
use constant BMP180_READTEMPCMD         => 0x2E;
use constant BMP180_READPRESSURECMD     => 0x34;

# Define a list of variables to store the calibration data into.

my $cal_AC1     = 0;
my $cal_AC2     = 0;
my $cal_AC3     = 0;
my $cal_AC4     = 0;
my $cal_AC5     = 0;
my $cal_AC6     = 0;
my $cal_B1      = 0;
my $cal_B2      = 0;
my $cal_MB      = 0;
my $cal_MC      = 0;
my $cal_MD      = 0;

# The Device::SMBus module provides methods for reading 8 and 16 bit values
# from the sensor, but these methods don't differentiate between signed and
# unsigned values. We need to create our own functions to read signed values
# and handle them correctly.

sub readS8 {
        my ($bmp180,$register) = @_;
        my $readVal = $bmp180->readByteData($register);
        if($readVal > 127) {
                $readVal -= 256;
        }
        return $readVal;
}

sub readS16 {
        my ($bmp180,$register) = @_;
        my $readValHi = readS8($bmp180,$register);
        my $readValLo = $bmp180->readByteData($register+1);
        my $bufferHi = $readValHi << 8;
        my $retVal = $bufferHi + $readValLo;
        return $retVal;
}

sub readU16 {
        my ($bmp180,$register) = @_;
        my $readValHi = $bmp180->readByteData($register);
        my $readValLo = $bmp180->readByteData($register+1);
        my $bufferHi = $readValHi << 8;
        my $retVal = $bufferHi + $readValLo;
        return $retVal;
}

# Read the calibration data from the sensor's eeprom and store it locally

$cal_AC1 = readS16($bmp180,BMP180_CAL_AC1);
$cal_AC2 = readS16($bmp180,BMP180_CAL_AC2);
$cal_AC3 = readS16($bmp180,BMP180_CAL_AC3);
$cal_AC4 = readU16($bmp180,BMP180_CAL_AC4);
$cal_AC5 = readU16($bmp180,BMP180_CAL_AC5);
$cal_AC6 = readU16($bmp180,BMP180_CAL_AC6);
$cal_B1  = readS16($bmp180,BMP180_CAL_B1);
$cal_B2  = readS16($bmp180,BMP180_CAL_B2);
$cal_MB  = readS16($bmp180,BMP180_CAL_MB);
$cal_MC  = readS16($bmp180,BMP180_CAL_MC);
$cal_MD  = readS16($bmp180,BMP180_CAL_MD);

# Read the raw (uncompensated) temperature from the sensor

sub readRawTemp {
        my ($bmp180) = @_;
        $bmp180->writeByteData(BMP180_CONTROL,BMP180_READTEMPCMD);
        # usleep takes microseconds, so this is 5 milliseconds
        usleep(5000);
        my $rawTemp = readU16($bmp180,BMP180_TEMPDATA);
        if(DIAG eq "True") {
                my $temp = $rawTemp & 0xFFFF;
                printf "Raw Temp: 0x%x (%d)\n", $temp, $rawTemp;
        }
        return $rawTemp;
}

# Read the raw (uncompensated) barometric pressure from the sensor

sub readRawPressure {
        my ($bmp180,$mode) = @_;
        my $writeVal = BMP180_READPRESSURECMD + ($mode << 6);
        $bmp180->writeByteData(BMP180_CONTROL,$writeVal);
        if ($mode == BMP180_ULTRALOWPOWER) {
                usleep(5000);
        }
        elsif ($mode == BMP180_HIRES) {
                usleep(14000);
        }
        elsif ($mode == BMP180_ULTRAHIRES) {
                usleep(26000);
        }
        else {
                usleep(8000);
        }
        my $msb = $bmp180->readByteData(BMP180_PRESSUREDATA);
        my $lsb = $bmp180->readByteData(BMP180_PRESSUREDATA+1);
        my $xlsb = $bmp180->readByteData(BMP180_PRESSUREDATA+2);
        my $rawPressure = (($msb << 16) + ($lsb << 8) + $xlsb) >> (8 - $mode);
        if(DIAG eq "True") {
                my $press =  $rawPressure & 0xFFFF;
                printf "Raw Pressure value: 0x%X (%d)\n", $press, $rawPressure;
        }
        return $rawPressure;
}

# Read the compensated temperature

sub readTemp {
        my ($bmp180) = @_;
        my $UT = 0;
        my $X1 = 0;
        my $X2 = 0;
        my $B5 = 0;
        my $temp = 0.0;

        $UT = readRawTemp($bmp180);
        use integer;
        $X1 = (($UT - $cal_AC6) * $cal_AC5) >> 15;
        $X2 = ($cal_MC << 11) / ($X1 + $cal_MD);
        $B5 = $X1 + $X2;
        no integer;
        $temp = (($B5 + 8) >> 4) / 10.0;
        return $temp;
}

# Read the compensated barometric pressure

sub readPressure {
        my ($bmp180,$mode) = @_;
        my $UT = readRawTemp($bmp180);
        my $UP = readRawPressure($bmp180,$mode);

        # Calculate true temperature, but don't convert to simple output format yet
        use integer;
        my $X1 = (($UT - $cal_AC6) * $cal_AC5) >> 15;
        my $X2 = ($cal_MC << 11) / ($X1 + $cal_MD);
        my $B5 = $X1 + $X2;
        no integer;
        my $temp = (($B5 + 8) >> 4) / 10.0;

        # Calculate compensated pressure
        use integer;
        my $B6 = $B5 - 4000;
        #printf "B6 = $B6\n";
        my $X1 = ($cal_B2 * ($B6 * $B6) >> 12) >> 11;
        #printf "X1 = $X1\n";
        my $X2 = ($cal_AC2 * $B6) >> 11;
        my $X3 = $X1 + $X2;
        my $B3 = ((($cal_AC1 * 4 + $X3) << $mode) + 2) /4;
        $X1 = ($cal_AC3 * $B6) >> 13;
        $X2 = ($cal_B1 * (($B6 * $B6)) >> 12 ) >> 16;
        $X3 = (($X1 + $X2) + 2) >> 2;
        my $B4 = ($cal_AC4 * ($X3 + 32768)) >> 15;
        my $B7 = ($UP - $B3) * (50000 >> $mode);
        my $p = 0;
        if ($B7 < 0x80000000) {
                $p = ($B7 * 2) / $B4;
        } else {
                $p = ($B7 / $B4) * 2;
        }
        $X1 = ($p >> 8) * ($p >> 8);
        $X1 = ($X1 * 3038) >> 16;
        $X2 = (-7357 * $p) >> 16;
        $p = $p + (($X1 + $X2 + 3791) >> 4);
        #printf "Calibration pressure is %d Pa\n", $p;
        return $p;
}


