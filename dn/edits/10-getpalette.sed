# reason: (a) the new TV. The palette of a view in tv/ is a TPalette (an array of colors, built by
# MakePalette from the string of indexes), in Borland TV it is a pointer to the string: DN overrides
# GetPalette as `function GetPalette: PPalette` and returns `@S` for a local string S.
s/\(GetPalette[[:space:]]*:[[:space:]]*\)PPalette/\1TPalette/I
s/\(GetPalette[[:space:]]*:=[[:space:]]*\)@\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*;/\1MakePalette(\2);/I
