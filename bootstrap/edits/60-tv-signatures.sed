# reason: (a) the new TV. Signatures of the virtual methods that differ between Borland TV (as DN overrides
# them) and tv/ (the C++ original of magiblot): the override must match exactly.
s/function \([A-Za-z_]*\.\)\{0,1\}DataSize: Word/function \1DataSize: Integer/
s/procedure \([A-Za-z_]*\.\)\{0,1\}ChangeBounds(var \([A-Za-z_]*\): TRect)/procedure \1ChangeBounds(const \2: TRect)/
# streams: the count is a LongInt (Word is 16 bits in FPC, 32 in VP); Write takes the buffer as const
s/\(procedure [A-Za-z_.]*Read(var Buf; Count: \)\(Word\|SW_Word\|Integer\))/\1LongInt)/
s/\(procedure [A-Za-z_.]*Write(\)\(var\|const\) Buf; Count: \(Word\|SW_Word\|Integer\))/\1const Buf; Count: LongInt)/
# TSortedListBox.GetKey takes the string as const in tv/
s/function \([A-Za-z_]*\.\)\{0,1\}GetKey(var \([A-Za-z_]*\): String)/function \1GetKey(const \2: String)/
