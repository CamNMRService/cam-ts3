REM cd \Users
REM dir /A:D /B > users.txt
FOR /f "delims=" %%U in (users.txt) DO copy "c:\bruker\cam-ts3\serv-windows-parfile-dirs.prop" "C:\Users\%%U\.topspin-AUCHENTOSHAN\prop\parfile-dirs.prop"
