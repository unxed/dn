# reason: (a) the new TV. Signatures of the virtual methods that differ between Borland TV (as DN overrides
# them) and tv/ (the C++ original of magiblot): the override must match exactly.
s/function \([A-Za-z_]*\.\)\{0,1\}DataSize: Word/function \1DataSize: Integer/
s/procedure \([A-Za-z_]*\.\)\{0,1\}ChangeBounds(var \([A-Za-z_]*\): TRect)/procedure \1ChangeBounds(const \2: TRect)/
