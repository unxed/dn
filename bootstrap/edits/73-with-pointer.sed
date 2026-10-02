# reason: (д) the modern compiler. `with P do` with a pointer to an object (VP/Delphi accept it); FPC wants the
# object itself. Only the variables that the compiler reported.
s/^\([ \t]*\)with \(Manager\|ThisPanel\) do\([ \t\r]*\)$/\1with \2^ do\3/
# the same for `with T^.Strings do` (a pointer field) and `with PButton(DirectLink[b]) do` (a cast to a pointer type)
s/^\([ \t]*\)with \(T^\.Strings\) do\([ \t\r]*\)$/\1with \2^ do\3/
s/^\([ \t]*\)with \(P[A-Z][A-Za-z]*([A-Za-z]*\(\[[A-Za-z0-9]*\]\)\{0,1\})\) do\([ \t\r]*\)$/\1with \2^ do\4/
s/^\([ \t]*\)with \(ToggleItem\[[A-Za-z0-9]*\]\) do\([ \t\r]*\)$/\1with \2^ do\3/
# `with` over a call that returns a pointer (a cast to a pointer type with a call inside, a function of an object)
s/^\([ \t]*\)with \(P[A-Z][A-Za-z]*(.*)\) do\([ \t\r]*\)$/\1with \2^ do\3/
s/^\([ \t]*\)with \([A-Za-z_]*^\.NewItem(.*)\) do\([ \t\r]*\)$/\1with \2^ do\3/
