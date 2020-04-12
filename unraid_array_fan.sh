#!/bin/bash
# Finding your fan controllers: find -L /sys/class/hwmon/ -maxdepth 5 -iname "pwm[0-9]" 2>/dev/null
# /sys/class/hwmon/hwmon3/pwm1  FAN 0 - FAN 5
# /sys/class/hwmon/hwmon3/pwm2  FAN 6 - FAN 7
# Original script: https://forums.unraid.net/topic/5375-temperature-based-fan-speed-control/?tab=comments#comment-51790

# unraid_array_fan.sh v0.5
# v0.1  First try at it.
# v0.2: Made a small change so the fan speed on low doesn't fluctuate every time the script is run.
# v0.3: It will now enable fan speed change before trying to change it. I missed 
#	it at first because pwmconfig was doing it for me while I was testing the fan.
# v0.4: Corrected temp reading to "Temperature_Celsius" as my new Seagate drive
# v0.5: Customized the script for my own use.
#	was returning two numbers with just "Temperature".
# A simple script to check for the highest hard disk temperatures in an array
# or backplane and then set the fan to an apropriate speed. Fan needs to be connected
# to motherboard with pwm support, not array.
# DEPENDS ON:grep,awk,smartctl,hdparm
# v0.6: The pwm that is used switches randomly on reboot. Easier to set them all.

### VARIABLES FOR USER TO SET ###
# Amount of drives in the array. Make sure it matches the amount you filled out below.
NUM_OF_DRIVES=26

# unRAID drives that are in the array/backplane of the fan we need to control
HD[1]=/dev/sdb
HD[2]=/dev/sdc
HD[3]=/dev/sdd
HD[4]=/dev/sde
HD[5]=/dev/sdf
HD[6]=/dev/sdg
HD[7]=/dev/sdh
HD[8]=/dev/sdi
HD[9]=/dev/sdj
HD[10]=/dev/sdk
HD[11]=/dev/sdl
HD[12]=/dev/sdm
HD[13]=/dev/sdn
HD[14]=/dev/sdo
HD[15]=/dev/sdp
HD[16]=/dev/sdq
HD[17]=/dev/sdr
HD[18]=/dev/sds
HD[19]=/dev/sdt
HD[20]=/dev/sdu
HD[21]=/dev/sdv
HD[22]=/dev/sdw
HD[23]=/dev/sdx
HD[24]=/dev/sdy
HD[25]=/dev/sdz
HD[26]=/dev/sdaa

# Temperatures to change fan speed at
# Any temp between OFF and HIGH will cause fan to run on low speed setting 
FAN_OFF_TEMP=35		# Anything this number and below - fan is off
FAN_HIGH_TEMP=40	# Anything this number or above - fan is high speed

# Fan speed settings. Run pwmconfig (part of the lm_sensors package) to determine 
# what numbers you want to use for your fan pwm settings. Should not need to
# change the OFF variable, only the LOW and maybe also HIGH to what you desire.
# Any real number between 0 and 255.
FAN_OFF_PWM=100
FAN_LOW_PWM=150
FAN_HIGH_PWM=255

# Fan device. Depends on your system. pwmconfig can help with finding this out. 
# pwm1 is usually the cpu fan. You can "cat /sys/class/hwmon/hwmon0/device/fan1_input"
# or fan2_input and so on to see the current rpm of the fan. If 0 then fan is off or 
# there is no fan connected or motherboard can't read rpm of fan.
# ARRAY_FAN=/sys/class/hwmon/hwmon1/device/pwm2
# ARRAY_FAN = FAN 0-5. ARRAY_FAN_TWO = 6-7 
ARRAY_FAN=/sys/class/hwmon/hwmon3/pwm1
ARRAY_FAN_TWO=/sys/class/hwmon/hwmon3/pwm2
ARRAY_FAN_THREE=/sys/class/hwmon/hwmon3/pwm3
ARRAY_FAN_FOUR=/sys/class/hwmon/hwmon3/pwm4

### END USER SET VARIABLES ###

# Program variables - do not modify
HIGHEST_TEMP=0
CURRENT_DRIVE=1
CURRENT_TEMP=0

# while loop to get the highest temperature of active drives. 
# If all are spun down then high temp will be set to 0.
while [ "$CURRENT_DRIVE" -le "$NUM_OF_DRIVES" ]
do
 SLEEPING=`hdparm -C ${HD[$CURRENT_DRIVE]} | grep -c standby`
 if [ "$SLEEPING" == "0" ]; then
   CURRENT_TEMP=`smartctl -A ${HD[$CURRENT_DRIVE]} | grep -m 1 -i Temperature_Celsius | awk '{print $10}'`
   if [ "$HIGHEST_TEMP" -le "$CURRENT_TEMP" ]; then
     HIGHEST_TEMP=$CURRENT_TEMP
   fi
 fi
#echo $CURRENT_TEMP
 let "CURRENT_DRIVE+=1"
done
echo "Highest temp is: "$HIGHEST_TEMP

# Enable speed change on this fan if not already
if [ "$ARRAY_FAN" != "1" ]; then
 echo 1 > "${ARRAY_FAN}_enable"
 echo 1 > "${ARRAY_FAN_TWO}_enable"
 echo 1 > "${ARRAY_FAN_THREE}_enable"
 echo 1 > "${ARRAY_FAN_FOUR}_enable"
fi

# Set the fan speed based on highest temperature
if [ "$HIGHEST_TEMP" -le "$FAN_OFF_TEMP" ]; then
 # set fan to off
 echo $FAN_OFF_PWM > $ARRAY_FAN
 echo $FAN_OFF_PWM > $ARRAY_FAN_TWO
 echo $FAN_OFF_PWM > $ARRAY_FAN_THREE
 echo $FAN_OFF_PWM > $ARRAY_FAN_FOUR
 echo "Setting pwm to: "$FAN_OFF_PWM
 elif [ "$HIGHEST_TEMP" -ge "$FAN_HIGH_TEMP" ]; then
   # set fan to full speed
   echo $FAN_HIGH_PWM > $ARRAY_FAN
   echo $FAN_HIGH_PWM > $ARRAY_FAN_TWO
   echo $FAN_HIGH_PWM > $ARRAY_FAN_THREE
   echo $FAN_HIGH_PWM > $ARRAY_FAN_FOUR
   echo "Setting pwm to: "$FAN_HIGH_PWM
 else
   CURRENT_SPEED=`cat $ARRAY_FAN`
   # set fan to full speed first to make sure it spins up then change it to low setting.
   if [ "$CURRENT_SPEED" -lt "$FAN_LOW_PWM" ]; then
     echo $FAN_HIGH_PWM > $ARRAY_FAN
     echo $FAN_HIGH_PWM > $ARRAY_FAN_TWO
     echo $FAN_HIGH_PWM > $ARRAY_FAN_THREE
     echo $FAN_HIGH_PWM > $ARRAY_FAN_FOUR
     sleep 2
   fi
   echo $FAN_LOW_PWM > $ARRAY_FAN
   echo $FAN_LOW_PWM > $ARRAY_FAN_TWO
   echo $FAN_LOW_PWM > $ARRAY_FAN_THREE
   echo $FAN_LOW_PWM > $ARRAY_FAN_FOUR
   echo "Setting pwm to: "$FAN_LOW_PWM
fi