# reason: (a) the new TV. TInputLine.Data of DN is a string variable, in tv/ a pointer to a ShortString; THexLine (carved
# into dndlgs.pas) works with the text of its input line.
/^\(procedure\|function\|constructor\)/!s/\bInputLine^\.Data\b\([^^]\)/InputLine^.Data^\1/g
