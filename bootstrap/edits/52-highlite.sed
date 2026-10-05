# reason: (d) the modern compiler. InsertHighliteRule of highlite.pas indexes an array by Succ(High(enum)): VP
# lets a constant go beyond the enumeration, FPC does not. The array is indexed by numbers (the first
# member of the enumeration is 0, so the positions are the same).
s/exrules: array\[Low(THighliteRule)\.\.Succ(High(THighliteRule))\] of PChar;/exrules: array[0..Ord(High(THighliteRule))+1] of PChar;/
s/exrules\[Succ(Index)\]/exrules[Ord(Index)+1]/
