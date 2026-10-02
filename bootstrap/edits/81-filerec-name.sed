# reason: (д) the modern compiler. FileRec.Name/TextRec.Name are arrays of wide characters in FPC (of Char in VP);
# StrPas_ wants Char. NameOfRec (dn/new/vputils.pas) converts (the names are DOS names: one byte per character).
s/StrPas_(\(FileRec\|TextRec\)(\([A-Za-z.]*\))\.Name)/NameOfRec(\1(\2).Name)/
