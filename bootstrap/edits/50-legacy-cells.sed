# reason: (a) the new TV. DN draws with 16-bit cells (Word: character + BIOS attribute) and takes colors as
# BIOS attributes (Word), as Turbo Vision for Borland Pascal does; TView of tv/ has these as WriteBufW,
# WriteLineW and GetColorW (tv/DESIGN.md, 11c); the names of tv/ without W are for TScreenCell.
s/\([^A-Za-z0-9_]\)WriteBuf(/\1WriteBufW(/g
s/\([^A-Za-z0-9_]\)WriteLine(/\1WriteLineW(/g
s/\([^A-Za-z0-9_]\)GetColor(/\1GetColorW(/g
