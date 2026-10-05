#!/bin/sh
# reason: (d) the modern compiler. DN is written for $V- (a string variable parameter may have another length,
# as in Virtual Pascal and Turbo Pascal); FPC in the Delphi mode has $V+. STDEFINE.INC is included at the head
# of nearly every unit: the directive is added to it. Also {$modeswitch nestedprocvars}: @Name of a routine
# declared inside another one (FirstThat(@IsButton), ForEach(@DoPlay)) is a procedure variable of the nested kind,
# which the collections and groups of tv/ take. Also the switches of vpc.cfg that are not the defaults of FPC: $I- (no
# exception on an I/O error: DN looks at IOResult), $J+ (typed constants are variables), $B- $R- $Q-.
f=$(ls "$1" | grep -i '^stdefine\.inc$' | head -1)
[ -n "$f" ] && printf '\r\n{$V-}\r\n{$modeswitch nestedprocvars}\r\n{$I-}\r\n{$J+}\r\n{$B-}\r\n{$R-}\r\n{$Q-}\r\n{$PACKRECORDS 1}\r\n' >> "$1/$f"
exit 0
