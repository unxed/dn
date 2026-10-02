# reason: (д) the modern compiler. `with Manager do` with a pointer to an object (VP/Delphi accept it); FPC wants the
# object itself. Only the places that the compiler reported.
s/^\([ \t]*\)with Manager do\([ \t\r]*\)$/\1with Manager^ do\2/
