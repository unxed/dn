# reason: the 64-bit build. The parameters of FormatStr/Msg are an array of slots that hold numbers and pointers (Pointer(L[0]) := @S in the
# source of Virtual Pascal, where both are 32 bits). A slot is as large as a pointer: PtrInt (see FormatStr in dn/new/drivers.pas).
s/^\([ \t]*[Ll][ \t]*:[ \t]*array\[[0-9.]*\][ \t]*of[ \t]*\)LongInt;/\1PtrInt;/
