# reason: (д) the modern compiler. In VP `Comp` is a 64-bit integer that is compatible with Int64 (TFileSize); in FPC it
# is a floating type, not assignable to Int64 and without div/mod/shr. Int64 is what DN means (sizes, positions).
s/\bComp\b/Int64/g
