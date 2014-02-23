#!//bin/bash

# Generate the Temperature graphs
/usr/bin/rrdtool graph /var/www/temperature.png -a PNG -w 800 -t "Temperature Data" --vertical-label "Temperature" --end now --start -86400 --slope-mode DEF:tempF=/var/lib/RPiWeather/rrd/rhtp.rrd:tempF:AVERAGE LINE1:tempF#0000ff:"Temperature (F)" VDEF:LastF=tempF,LAST VDEF:AvgF=tempF,AVERAGE GPRINT:LastF:"Current\: %3.2lfF" GPRINT:AvgF:"Average\: %3.2lfF" VDEF:maxF=tempF,MAXIMUM GPRINT:maxF:"Max\: %3.2lfF" VDEF:minF=tempF,MINIMUM GPRINT:minF:"Min\: %3.2lfF\n" DEF:tempC=/var/lib/RPiWeather/rrd/rhtp.rrd:tempC:AVERAGE LINE2:tempC#ff0000:"Temperature (C)" VDEF:LastC=tempC,LAST GPRINT:LastC:"Current\: %3.2lfC" VDEF:AvgC=tempC,AVERAGE GPRINT:AvgC:"Average\: %3.2lfC" VDEF:maxC=tempC,MAXIMUM VDEF:minC=tempC,MINIMUM GPRINT:maxC:"Max\: %3.2lfC" GPRINT:minC:"Min\: %3.2lfC\n" GPRINT:LastF:"Created on %c":strftime

# Generate the Relative Humidity graph
/usr/bin/rrdtool graph /var/www/humidity.png -a PNG -w 800 -t "Humidity Data" --vertical-label "Relative Humidity" --end now --start -86400 --slope-mode DEF:humidity=/var/lib/RPiWeather/rrd/rhtp.rrd:humidity:AVERAGE LINE1:humidity#00ff00:"Relative Humidity (%)" VDEF:rhL=humidity,LAST VDEF:rhA=humidity,AVERAGE VDEF:rhMax=humidity,MAXIMUM VDEF:rhMin=humidity,MINIMUM GPRINT:rhL:"Current\: %3.2lf%%" GPRINT:rhA:"Average\: %3.2lf%%" GPRINT:rhMax:"Maximum\: %3.2lf%%" GPRINT:rhMin:"Minimum\: %3.2lf%%\n" GPRINT:rhL:"Created on %c":strftime

# Generate the Barometric Pressure Graph
/usr/bin/rrdtool graphv /var/www/pressure.png -a PNG -w 800 -t "Pressure Data" --vertical-label "Barometric Pressure" --end now --start -86400 --slope-mode DEF:pressure=/var/lib/RPiWeather/rrd/rhtp.rrd:pressure:AVERAGE CDEF:inHg=pressure,0.0295333727,* LINE1:inHg#aa00aa:"Barometric Pressure (inHg)" VDEF:pL=inHg,LAST VDEF:pA=inHg,AVERAGE VDEF:pMax=inHg,MAXIMUM VDEF:pMin=inHg,MINIMUM GPRINT:pL:"Current\: %3.2lfinHg" GPRINT:pA:"Average\: %3.2lfinHg" GPRINT:pMax:"Maximum\: %3.2lfinHg" GPRINT:pMin:"Minimum\: %3.2lfinHg\n" GPRINT:pL:"Created on %c":strftime

