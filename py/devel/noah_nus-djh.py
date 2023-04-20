from __future__ import with_statement
"""
noah_nus.py

TopSpin python script to setup NUS for NOAH experiments
Author: Maksim Mayzel, maksim.mayzel@bruker.com
Date: 2019-03-19
Changes August 2019: Duncan Howe, Cambridge University djh35@cam.ac.uk
   -Gets random seed from parameter set
   -Makes a (probably) unique sampling list name using (unix) epoch time in seconds
    (I've found in the past VCLIST/NUS list name longer than 32 characters get truncated when the pp is interpreted.
   -Saves sampling list  into data set, along with nussampler command
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
    ###DJH additions
    ###Make full path to nus-sampling list. List name will be noah+unix time in seconds
    seconds = str(int(time.time()))
    nusprefix = 'noah'
    nuslist_time = nusprefix+seconds
    ###Full path to experiment expno. Using unix path syntax, to avoid mangling.
    cur_data_expno = str(CURDATA()[3]+"/"+CURDATA()[0]+"/"+CURDATA()[1]+"/") 
    nuslist=os.path.join(VC,nuslist_time)
    cur_data_nuslist = cur_data_expno+nuslist_time
    ###End DJH additions
    dim=2
    ###seed=random.randint(0,1000) -- Change by DJH
    seed=int(GETPAR('NusSEED'))
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
    #MSG('nussampler command = %s'%nusstr)
    ecode=os.system(nusstr)
    if ecode:
        ERRMSG('nussampler exit code %s'%ecode)
        EXIT()

    ###DJH additions
    ###Save all these variables back into the parameter set
    PUTPAR('VCLIST',nuslist_time)
    ###Copy the nuslist into the current data set. shutil.copyfile should hopefully avoid DOS pathname syntax problems
    shutil.copyfile(nuslist, cur_data_nuslist)
    PUTPAR("NusSEED", str(seed))
    PUTPAR("NUSLIST", nuslist_time)
    ###Save the command used to generate the schedule
    f_stat_file = cur_data_expno+"/"+"noah_nus_status.txt"
    ###is open smart enough to deal with DOS/Windows pathname? We'll find out...
    f_stat = open(f_stat_file,"w+")
    f_stat.write("nussampler command = ")
    f_stat.write(nusstr)
    f_stat.close()
    ###end of DJH additions
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
