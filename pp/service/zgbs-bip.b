;zgbs-bip.b
;avance-version (02/05/31)
;1D sequence for suppression of background signals
;using composite pulse with shaped 180s (BIP)
;
;D.G. Cory & W.M. Ritchey, J. Magn. Reson. 80, 128-132 (1988)
;
;PTG:
; Timing corrected for effect of finite excitation pulse and DE
; With additional delay D3 if you want to have more T2 filter (probabl;y not)
; Using P0 to allow smaller flip angle
;$CLASS=HighRes
;$DIM=1D
;$TYPE=
;$SUBTYPE=
;$COMMENT=


#include <Avance.incl>
#include <Delay.incl>

"p2=p1*2"
"TAU=de+(tan((p0/p1)*(PI/4))*p1*2/PI)"
"acqt0=0"
baseopt_echo


1 ze
2 30m 
  d1 pl1:f1
  (p0 ph1):f1 
  d3
  (p44:sp30 ph2):f1
  d3
  TAU
  d3  
  (p44:sp30 ph3):f1
  d3
  go=2 ph31 
  30m mc #0 to 2 F0(zd)
exit


ph1=0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3
ph2=0 1 2 3
ph3=0 0 0 0 2 2 2 2 3 3 3 3 1 1 1 1
ph31=0 2 0 2 1 3 1 3


;pl1 : f1 channel - power level for pulse (default)
;p1 : f1 channel -  90 degree high power pulse
;p44 : f1 channel - 180 degree shaped pulse
;sp30: f1 channel - shaped pulse for inversion
;d1 : relaxation delay; 1-5 * T1
;d3: additional delay in spin echoes for T2 filtering [0 if not required]
;NS:  16 * n, total number of scans: NS * TD0



;$Id: zgbs,v 1.3 2009/07/02 16:40:47 ber Exp $
