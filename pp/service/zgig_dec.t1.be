;zgig_dec.t1.be
;avance-version (11/10/18)
;1D sequence with inverse gated decoupling
;explicit p5m4 decoupling
;
;$CLASS=HighRes
;$DIM=1D
;$TYPE=
;$SUBTYPE=
;$COMMENT=


#include <Avance.incl>
#include <De.incl>


"d11=30m"


"l1=trunc(aq/(p63*20))+1"


"acqt0=-p1*2/3.1416"


1 ze
  d11 pl12:f2
2 30m
  d1 
  20u pl1:f1
  p1 ph1
  ACQ_START(ph30,ph31)
  2u DWELL_GEN:f1

4 (p63:sp31 ph21):f2
  (p63:sp31 ph23):f2
  (p63:sp31 ph22):f2
  (p63:sp31 ph23):f2
  (p63:sp31 ph21):f2
  (p63:sp31 ph21):f2
  (p63:sp31 ph23):f2
  (p63:sp31 ph22):f2
  (p63:sp31 ph23):f2
  (p63:sp31 ph21):f2
  (p63:sp31 ph24):f2
  (p63:sp31 ph26):f2
  (p63:sp31 ph25):f2
  (p63:sp31 ph26):f2
  (p63:sp31 ph24):f2
  (p63:sp31 ph24):f2
  (p63:sp31 ph26):f2
  (p63:sp31 ph25):f2
  (p63:sp31 ph26):f2
  (p63:sp31 ph24):f2
  lo to 4 times l1
  rcyc=2
  30m mc #0 to 2 F0(zd)
exit


ph1=0 2 2 0 1 3 3 1

ph21=(360) 0
ph22=(360) 60
ph23=(360) 150
ph24=(360) 180
ph25=(360) 240
ph26=(360) 330

ph29=0
ph30=0
ph31=0 2 2 0 1 3 3 1


;pl1 : f1 channel - power level for pulse (default)
;pl12: f2 channel - power level for CPD/BB decoupling
;p1 : f1 channel -  high power pulse
;d1 : relaxation delay; 1-5 * T1
;d11: delay for disk I/O                             [30 msec]
;NS: 1 * n, total number of scans: NS * TD0
;cpd2: decoupling according to sequence defined by cpdprg2
;pcpd2: f2 channel - 90 degree pulse for decoupling sequence



;$Id: $
