;zgbs-bip-ig.b
;avance-version (02/05/31)
;1D sequence for suppression of background signals
;using composite pulse with shaped 180s (BIP)
;
;D.G. Cory & W.M. Ritchey, J. Magn. Reson. 80, 128-132 (1988)
;
;$CLASS=HighRes
;$DIM=1D
;$TYPE=
;$SUBTYPE=
;$COMMENT=


#include <Avance.incl>


"p2=p1*2"
"acqt0=-p1*2/3.14159"

1 ze
2 30m do:f2
  d1 
  4u pl12:f2
  (p1 ph1):f1 
  (p44:sp30 ph2):f1
  (p44:sp30 ph3):f1
  go=2 ph31 cpd2:f2
  30m do:f2 mc #0 to 2 F0(zd)
exit


ph1=0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3
ph2=0 1 2 3
ph3=0 0 0 0 2 2 2 2 3 3 3 3 1 1 1 1
ph31=0 2 0 2 1 3 1 3


;pl1 : f1 channel - power level for pulse (default)
;p1 : f1 channel -  90 degree high power pulse
;p2 : f1 channel - 180 degree high power pulse
;d1 : relaxation delay; 1-5 * T1
;NS:  16 * n, total number of scans: NS * TD0



;$Id: zgbs,v 1.3 2009/07/02 16:40:47 ber Exp $
