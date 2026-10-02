# reason: (д) the modern compiler. `with P do` with a pointer to an object (VP/Delphi accept it); FPC wants the
# object itself. Only the variables that the compiler reported.
s/^\([ \t]*\)with \(Manager\|ThisPanel\) do\([ \t\r]*\)$/\1with \2^ do\3/
