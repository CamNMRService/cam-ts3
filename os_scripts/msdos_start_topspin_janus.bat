SET file=E:\chemist\spect_rebooting.txt
IF EXIST %file% (
  ECHO %file% is existing
  DEL %file%
) 
C:\Bruker\TopSpin3.6.5\topspin -s janus_sx_arran