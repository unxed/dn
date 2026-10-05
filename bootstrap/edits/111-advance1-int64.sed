# reason: (d) the modern compiler. TSize (the old Comp) is Int64: Str with a format `a: 0: 0` and `/` are for reals; integer forms.
s/MaxVal := MaxVal \/ 10;/MaxVal := MaxVal div 10;/
s/^\([ \t]*\)a := a\/1024;/\1a := a div 1024;/
s/Str(a: 0: 0, \(Result\|s\));/Str(a, \1);/
