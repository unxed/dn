# reason: (d) the modern compiler. In VP `Word` is 32 bit, so Dos.GetDate/GetTime take LongInt variables there; the
# FPC procedures want Word (16 bit). The variables of uucode.pas CurStdDateTime are Word here (values 0..9999).
s/^\([ \t]*\)Dummy, Year, Month, Day, Hour, Minute, Second: LongInt;/\1Dummy, Year, Month, Day, Hour, Minute, Second: Word;/
