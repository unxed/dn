# reason: (a) the new TV. TInputLine.Data of DN is a string variable (AnsiString of VP), in tv/ it is a pointer to
# a ShortString (PStr, as in Borland). Only the sites that the compiler named.
s/PInputLine(DirectLink\[i\])^\.Data = ''/PInputLine(DirectLink[i])^.Data^ = ''/
s/IL^\.Data := FileMask;/IL^.Data^ := FileMask;/
s/GetMaskSelection := #20+IL^\.Data;/GetMaskSelection := #20+IL^.Data^;/
s/System\.Insert(S, Data, 1+CurPos);/System.Insert(S, Data^, 1+CurPos);/
