:loop
    wget -r -nd --no-parent -A "*ewpres*"  http://149.236.99.107/ewp/device/main/Changer_Overview/
	move index* Documents/SXpresslog
	timeout /t 10
goto :loop