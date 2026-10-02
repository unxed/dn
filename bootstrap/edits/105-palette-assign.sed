# reason: (a) the new TV. DN assigns to the palette that GetPalette points to (`PV^.GetPalette^ := CScrollBar` makes
# a scroll bar of the viewer use another palette); tv/ palettes are values. The assignment is dropped (TODO: dn/TODO-later.md).
s/^\([ \t]*\)\([A-Za-z_^.]*\)GetPalette^[ ]*:=[ ]*\([A-Za-z_]*\);/\1{ TODO: palette \3 of \2 }/
