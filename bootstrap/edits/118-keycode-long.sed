# reason: (d) the modern compiler. In Virtual Pascal Word has 32 bits: the key codes of DN carry the shift state above the
# 16 bits of the key (kbAltX = $082D00, kbCtrlAltX = $0C2D00) and are stored in `KeyCode: Word` of the menu items and the
# status items; with the 16 bits of FPC Alt-X and Ctrl-Alt-X are the same key. LongInt where the key code is kept.
# Other places that assume the 32 bits of Word: dn/TODO-later.md ("Word of VP").
s/\([A-Za-z]*KeyCode\) *: *Word\b/\1: LongInt/g
