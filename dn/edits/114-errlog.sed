# reason: (e) the tests. DNErrLog (dn/new) is the first unit of the program: its error output can go to a file in DOSBox-X.
/^uses[ \t\r]*$/{
n
n
s/^  Drivers, Lfn, Files,/  DNErrLog, Drivers, Lfn, Files,/
}
# the stack of an exception goes to the trace (test aid): the handler of dn.pas
/^  on E: Exception do[ \t\r]*$/{
n
a\
    DNErrLog.DNTraceException;
}
