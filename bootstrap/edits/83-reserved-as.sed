# reason: (д) the modern compiler. `as` is a reserved word in the Delphi mode of FPC (the constant `as = 10` of the
# disassembler, a case label); renamed in decoder.pas only.
/^[ \t]*as[ \t]*=[ \t]*10;/s/\bas\b/as_/
/^[ \t]*as:[ \t\r]*$/s/\bas\b/as_/
