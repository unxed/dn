# reason: the 64-bit build. A number is put into a slot of an array of pointers by a typecast of the slot: LongInt(M[0]) := N. The slot is as large as
# a pointer, so the cast is of that size (PtrInt); the same for the arrays that hold numbers and pointers.
s/\b[Ll][Oo][Nn][Gg][Ii][Nn][Tt](\([A-Za-z_][A-Za-z0-9_]*\[[^]]*\]\)) :=/PtrInt(\1) :=/g
