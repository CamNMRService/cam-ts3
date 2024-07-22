while($true) {
	& "C:\Program Files\Putty\pscp.exe" -pw 'serv1ce' -batch nmr@pizero1.local:/home/nmr/templog.txt  C:\Bruker\Diskless\prog\logfiles\
	Start-Sleep -seconds 60
}