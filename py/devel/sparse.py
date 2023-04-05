import os
import math
import random
import time
curdata = CURDATA()
print '**************'
for items in curdata:
	print items
MSG("A tool to sparse Bruker parameter sets by Aleks Gutmanas and Murthy Karra")
MSG("Before running this program, make sure that all parameters have been set as in a regular experiment.\
\nMake sure that the total experiment time (Bruker command expt) is approxomately 3 times the desired time.\
\nFor example if you want to run the experiment for 2 days, the time shown by Bruker should be ~6 days")
cwd=os.getcwd()
MSG("break 1")

td1 = int(GETPAR("TD",1))
td2 = int(GETPAR("TD",2))
fastCplx=td2/2
slowCplx=td1/2

nucSlow=GETPAR("NUC1",1)
nucFast=GETPAR("NUC1",2)

if (nucFast=="15N"):
	T2spFast=50.0
elif (nucFast=="13C"):
	T2spFast=20.0
else:
	T2spFast=35.0

if (nucSlow=="15N"):
	T2spSlow=50.0
elif (nucSlow=="13C"):
	T2spSlow=20.0
else:
	T2spSlow=35.0

now=time.localtime()
year=int(now[0])%100
month=int(now[1])
day=int(now[2])
tday=day+100*month+10000*year
if (year<10):
	sday="0"+str(tday)
else:
	sday=str(tday)

datadir=curdata[3]+"\\data\\"+curdata[4]+"\\nmr\\"+curdata[0]+"\\"+curdata[1] 

try:
	ft=open(cwd+"\\vdstd",'r')
	vddir=ft.readline()
	vddir=vddir.strip()
	success=1
	ft.close()
except:
	vddir="C:\\Bruker\\TOPSPIN\\exp\\stan\\nmr\\lists\\vd"
	success=0

input = INPUT_DIALOG("Path to vdlist folder","Please modify if needed",["VDSTD"],[vddir])


if (vddir!=input[0].strip() or success==0):
	vddir=input[0].strip()
	message="Do you wish to write the new path into the standard file?\n"+vddir
	result = CONFIRM("Standard vdlist folder",message)
	if (result==1):
		ft=open(cwd+"\\vdstd",'w')
		ft.write(vddir+"\n")
		ft.close()

vdname="v"+sday+"_"+curdata[1]
sname="schedule"+curdata[1]


input = INPUT_DIALOG("Parameters","Please enter the following",\
["Level of Sparsing (>30), %", "T2 for Slow (F1, "+nucSlow+") dimension, ms",\
"T2sp for Fast (F2, "+nucFast+") dimension, ms","Random seed"],\
["30",str(T2spSlow),str(T2spFast),"709"])

sparse=0.01*float(input[0])
TspSlow=float(input[1])
TspFast=float(input[2])
rseed=int(input[3])

if (sparse<0.3) :
	MSG("Sparse level too low. Must be above 30. No VDLIST for you...")
	EXIT()

total=int(slowCplx*fastCplx*sparse)
if (total/(slowCplx*fastCplx) < sparse):
	total=total+1
	sparse=float(total)/(slowCplx*fastCplx)
	print "Sparse level recalculated to "+str(sparse*100)

print "Total number of hypercomplex points that will be recorded "+str(total)
swhSlow = float(GETPAR("SWH",1))
print swhSlow
swhFast = float(GETPAR("SWH",2))
print swhFast

P=0.0
tol=0.4
nminSlow=sparse*tol*slowCplx
if (nminSlow < 3):
	nminSlow=3

nminFast=sparse*tol*fastCplx
if (nminFast < 3):
	nminFast=3

print "nminFast ", nminFast 
print "nminSlow ", nminSlow

for k in range(slowCplx):
	for j in range(fastCplx):
		P=P+math.exp(-float(k)*1000.0/(swhSlow*TspSlow)-float(j)*1000.0/(swhFast*TspFast))

P=P/(1.0*slowCplx*fastCplx)
if (P<sparse):
	MSG("Consider increasing one or both of the T2 values as the distribution will be truncated. Proceeding anyway...")

Pf=sparse/P
Pff=1.0
ntot=2*total
random.seed(rseed)
checkSlow=[]
checkFast=[]
sel=[]

for k in range(slowCplx):
	checkSlow.append(0)
	
for j in range(fastCplx):
	checkFast.append(0)
	
for k in range(slowCplx):
	sel.append([])
	for j in range(fastCplx):
		sel[k].append(0)

iter=0
while ((ntot > total) and (iter < 10)):
	Pff=Pff*0.98
	ntot=0
	iter=iter+1
	print "iteration ", iter
	for k in range(slowCplx):
		checkSlow[k]=0
	for j in range(fastCplx):
		checkFast[j]=0
	for k in range(slowCplx):
		for j in range(fastCplx):
			temp=Pf*Pff*math.exp(-k*1000.0/(swhSlow*TspSlow)-j*1000.0/(swhFast*TspFast))
			if ((k==0) or (j==0) or (k==slowCplx-1 and j==fastCplx-1) or (random.random() < temp)):
				sel[k][j]=1
				ntot=ntot+1
				checkSlow[k]=checkSlow[k]+1
				checkFast[j]=checkFast[j]+1
			else:
				sel[k][j]=0
	print ntot, "points after main cycle"
	for k in range(slowCplx):
		while (checkSlow[k]<nminFast):
			j=random.randint(0,fastCplx-1)
			if (sel[k][j]==0):
				sel[k][j]=1
				ntot=ntot+1
				checkSlow[k]=checkSlow[k]+1
				checkFast[j]=checkFast[j]+1
	print ntot, "points after slow fix"
	for j in range(fastCplx):
		while (checkFast[j]<nminSlow):
			k=random.randint(0,slowCplx-1)
			if (sel[k][j]==0):
				sel[k][j]=1
				ntot=ntot+1
				checkSlow[k]=checkSlow[k]+1
				checkFast[j]=checkFast[j]+1
	print ntot, "points after fast fix"
	if (ntot>total):
		print "Too many points: "+str(ntot)+". Reducing probabilities and repeating the selection, Pff="+str(Pff)

while (ntot < total):
	k=random.randint(0,slowCplx-1)
	j=random.randint(0,fastCplx-1)
	if (sel[k][j]==0):
		sel[k][j]=1
		ntot=ntot+1

print "finally selected ",ntot," points"
print "writing vdlist and schedule files"
fv=open(datadir+"\\"+vdname,'w')
ft=open(vddir+"\\"+vdname,'w')
fs=open(datadir+"\\"+sname,'w')

for k in range(slowCplx):
	for j in range(fastCplx):
		if (sel[k][j]==1):
			fv.write("3u\n")
			ft.write("3u\n")
			fs.write("\t"+str(k)+"\t"+str(j)+"\n")
		else:
			fv.write("1u\n")
			ft.write("1u\n")
	for j in range(fastCplx):
		if (sel[k][j]==1):
			fv.write("3u\n")
			ft.write("3u\n")
		else:
			fv.write("1u\n")
			ft.write("1u\n")
			
fv.close()
fs.close()
ft.close()

XCMD("vdlist "+vdname)

MSG("The vdlist for sparse acquisition is created.\
\nFile "+vdname+" is copied to folder "+vddir+" and parameter vdlist is set accordingly.\
\nTotal number of FIDs to be recorded is 4*"+str(ntot)+" ("+str(4*ntot)+") out of 4*"+str(fastCplx)+"*"+str(slowCplx)+" ("+str(td1*td2)+")\
\nThe above file should have a total of "+str(2*fastCplx*slowCplx)+" records. Please check...\
\n The total experimental time will be approximately "+str(0.1*int(1000*sparse))+"% of the one reported by Bruker.")

print "done..."
