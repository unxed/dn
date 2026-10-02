# reason: (e) the tests. DNErrLog (dn/new) is the first unit of the program: its error output can go to a file in DOSBox-X.
/^uses[ \t\r]*$/{
n
n
s/^  Drivers, Lfn, Files,/  DNErrLog, Drivers, Lfn, Files,/
}
