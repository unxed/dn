# reason: (д) the modern compiler. Word of VP has 32 bits: `Key-Index^[I].Key < Index^[I].Count` with Key below the first key
# of the range wraps to a huge number and is false. With the 16 bits of AWord the difference is negative (computed in 32 bits)
# and the range matches: the strings of the language file came out empty. Word() restores the wrap-around.
s/if  ( (Key-Index^\[I\]\.Key) < Index^\[I\]\.Count) then/if  (Word(Key-Index^[I].Key) < Index^[I].Count) then/
