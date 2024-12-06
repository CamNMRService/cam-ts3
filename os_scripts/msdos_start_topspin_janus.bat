SET file=E:\chemist\spect_rebooting.txt
IF EXIST %file% (
  ECHO %file% is existing
  DEL %file%
) 
C:\Bruker\TopSpin3.7.0\topspin -s janus_sx_arran