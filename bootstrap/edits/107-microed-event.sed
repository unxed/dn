# reason: (a) the new TV. Inside `with Event do` the fields CharCode (a Char in DN, a Byte in tv/) and KeyCode (a LongInt with the
# shift state in DN) are written out: Event.CharCode, DNKeyCode(Event) (edit 80 handles only the forms Event.CharCode).
s/^\([ \t]*\)if  (CharCode > #31)\([ \t\r]*\)$/\1if  (Event.CharCode > #31)\2/
s/^\([ \t]*\)and (KeyCode <> kbShiftGrayPlus)\([ \t\r]*\)$/\1and (DNKeyCode(Event) <> kbShiftGrayPlus)\2/
s/^\([ \t]*\)and (KeyCode <> kbShiftGrayMinus)\([ \t\r]*\)$/\1and (DNKeyCode(Event) <> kbShiftGrayMinus)\2/
