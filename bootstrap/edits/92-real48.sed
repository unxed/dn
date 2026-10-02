# reason: (д) the modern compiler. cellscol.pas stores the values of the cells as Real48 (6 bytes, Borland Real); FPC does not
# convert between Real48 and the other floating types. Double (8 bytes) is used: the files of the spreadsheet
# of this build are not the files of the original (dn/TODO-later.md).
s/^\([ \t]*Real[ \t]*=[ \t]*\)Real48\([ \t]*;\)/\1Double\2/
