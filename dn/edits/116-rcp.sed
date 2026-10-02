# reason: (a) the new TV. The color dialog of DN is made from the groups only (Init(Groups)); TColorDialog of tv/ takes a palette too (here empty:
# rcp only stores the dialog; the palette is given when the dialog is used).
s/^\([ \t]*\)New(D, Init(PP));/\1New(D, Init(MakePalette(''), PP));/
