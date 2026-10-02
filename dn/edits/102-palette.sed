# reason: (a) the new TV. GetPalette of tv/ returns a palette of attributes, DN has the palette as a string (SystemColors,
# which is the variable SystemColors of tv/, TvApp, here from the unit DNApp).
s/CurPal := Application^\.GetPalette^;/CurPal := SystemColors[appPalette];/
