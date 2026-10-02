# reason: (д) the modern compiler. fviewer.pas calls SysFileSeek of VPSysLow without naming the unit (in VP the unit
# comes with Streams) and raises an exception at an address (ReturnAddr: VP).
s/^  Lfn, Dos, Commands, DNHelp, Advance1, Advance2, U_KeyMap\([ \t\r]*\)$/  Lfn, Dos, VPSysLow, Commands, DNHelp, Advance1, Advance2, U_KeyMap\1/
s/raise E At ReturnAddr;/raise E;/
# StreamSize is a field of the streams of DN; GetSize gives the size in tv/ (the file of a viewer: the same).
s/Fl^\.StreamSize/Fl^.GetSize/g
# the result of SysFileSeek is a LongInt (the file offsets of the DOS API)
s/^\([ \t]*\)Temp: TFileSize;/\1Temp: LongInt;/
