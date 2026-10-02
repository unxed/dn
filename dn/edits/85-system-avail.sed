# reason: (д) the modern compiler. VP has MemAvail/MaxAvail in System (`System.MaxAvail`); FPC has not. They are in
# the unit Defines (dn/new/manual/defines.inc).
s/\bSystem\.\(MaxAvail\|MemAvail\)\b/Defines.\1/g
