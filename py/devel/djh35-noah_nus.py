from __future__ import with_statement
"""
noah_nus.py

TopSpin python script to setup NUS for NOAH experiments
Author: Maksim Mayzel, maksim.mayzel@bruker.com
Date: 2019-03-19
Usage: noah_nus
"""


import os
import shutil
import sys
import java.lang.System as System
import random
import time

from de.bruker.nmr.prsc.dbxml.ParfileLocator import getParfileDirs
import de.bruker.nmr.mfw.root.UtilPath as UtilPath
TSHOME=UtilPath.getTopspinHome()
TSPROG=os.path.join(TSHOME,'prog','bin')
VC=os.path.join(TSHOME,'exp','stan','nmr','lists','vc')

def getpulprogtext(ppnam):
    """
    Get pulprog text
    """
    ppdirs=getParfileDirs(0)
    pptext=None
    for d in ppdirs:
        pplst=os.listdir(d)
        if ppnam in pplst:
            with open(os.path.join(d,ppnam)) as f:
                pptext=f.readlines()
            break
    if not pptext:
        ERRMSG('%s not found'%ppnam)
        EXIT()
    return pptext

def savepulprog(ppnam,pptext,overwrite=True):
    """
    Save pulprog to user pp dir
    """
    ppdirs=getParfileDirs(0)
    ready=0
    for d in ppdirs:
        if 'user' not in d:
            continue
        # pplist=os.listdir(d)
        # if ppnam in pplist and not CONFIRM("NOAH NUS","%s exists. Overwrite?"%ppnam):
        #     ready=1
        #     break
        with open(os.path.join(d,ppnam),'w') as f:
            f.writelines(pptext)
            ready=1
        break
    if not ready:
        ERRMSG('Something went wrong.\n%s was not saved'%ppnam)
        EXIT()
    return

def editNoah(ppText):
    """
    Add NUS to NOAH
    """
    ppTextNew=[]
    ddef=''
    t1inc=0
    for line in ppText:
        if line.startswith('"in0'):
            ddef='"d0=in0*t1list+3u"\n'
        if line.startswith('"in10'):
            ddef+='"d10=in10*t1list+3u"\n'
        if line.startswith('"in20'):
            ddef+='"d20=in20*t1list+3u"\n'

        if "#include <Delay.incl" in line:
            line="%s\ndefine list<loopcounter> t1list=<$VCLIST>\n"%line
        if "4 50u UNBLKGRAD" in line:
            line='%s\n%s'%(line,ddef)
        if 'id0' in line or 'id10' in line or 'id20' in line:
            line='; %s'%line
            if not t1inc: #add t1list.inc only once
                line='1m t1list.inc\n%s'%line
                t1inc=1

        ppTextNew.append(line)
    return ppTextNew

def makenuslist():
    """
    Create sampling scheme
    """
    try:
        td=int(GETPAR('USERA1'))
    except:
        td=int(GETPAR("1 TD"))
    PUTPAR('USERA1',str(td))

    nbl=int(GETPAR("NBL"))
    ppnam=GETPAR("PULPROG")
    if not ppnam.startswith('noah%i'%nbl):
        ERRMSG("NBL %i does not correspond to PULPROG %s"%(nbl,ppnam))
        EXIT()
    nimax=int(td/nbl/2)
    ni=int(float(GETPAR('NusAMOUNT'))*nimax/100.)
    PUTPAR('1 TD',str(ni*2*nbl))

    system=System.getProperty('os.name')
    ext='.exe' if 'Windows' in system else ''
    nussampler=os.path.join(TSPROG,'nussampler'+ext)
    seconds = str(int(time.time()))
    nusprefix = 'noah'
    nustime = nusprefix+seconds
    cur_data = str(CURDATA()[3]+os.sep+CURDATA()[0]+os.sep+CURDATA()[1]+os.sep)
 
    ERRMSG("seconds = %s,nustime = %s, cur_data = %s"%(seconds,nustime,cur_data)) 
    nuslist=os.path.join(VC,nustime)
    dim=2
    seed=random.randint(0,1000)
    perms=0

    sptype='norepeatshuffle'
    nn='nn'
    zz='0 0'
    t2=GETPAR('1 NusT2')+' 1'
    sw=GETPAR('1 SWH')+' 1'
    nimax='%i 1'%nimax
    ni='%i 1'%ni

    nusstr='%s -p "file=%s" "NDIM=%s" "SPARSE=y" "SEED=%s"  \
    "sptype %s" "f180 %s" "CT_SP %s" "CEXP %s" "phase %s" "Jsp %s" "T2 %s" \
    "FIRST_POINT_ZERO 1" "nholes -1" "SW=%s" "NIMAX= %s" "NIMIN=%s" "NI=%s"'%\
    (nussampler,nuslist,dim,seed,sptype,nn,nn,nn,zz,zz,t2,sw,nimax,zz,ni)

    ecode=os.system(nusstr)
    if ecode:
        ERRMSG('nussampler exit code %s'%ecode)
        EXIT()

    PUTPAR('VCLIST',nustime)
    
    
    return

def converpp():
    """
    Convert NOAH pulse sequence to NUS compatible
    """
    ppnam=GETPAR('PULPROG')
    if ppnam.endswith('.nus'):
        return
    sourcedir=getParfileDirs(0)
    ppText=getpulprogtext(ppnam)
    ppText=editNoah(ppText)
    ppnam=ppnam+'.nus'
    savepulprog(ppnam,ppText)

    PUTPAR('PULPROG',ppnam)
    return

def main(argv=None):

    #print('--- noah.py ---')
    converpp()
    makenuslist()
    #print('----------------')
    return

if __name__ == "__main__":
    e = main()
