# reason: (a) the new TV, (д) the modern compiler. dnutil.pas: the day of the week goes to a LongInt variable (GetDateDow of
# VPUtils); the help window is compared with a view (different pointer types); the palette of the program is SystemColors.
s/GetDate(DT\.Year, DT\.Month, DT\.Day, Word(L));/GetDateDow(DT.Year, DT.Month, DT.Day, L);/
s/if P1 = HelpWnd then/if P1 = PView(HelpWnd) then/
s/Application^\.GetPalette^[ ]*:=/SystemColors[appPalette] :=/
