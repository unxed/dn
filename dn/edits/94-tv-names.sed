# reason: (a) the new TV. Names that differ from Borland TV (as DN uses them): the range of a scroll bar is MinVal/MaxVal in tv/
# (Min and Max are functions there); TFileDialog.GetFileName is a function (DN: a procedure with a variable).
s/\b\(HScroll\|VScroll\|VSB\|HSB\)^\.Max\b/\1^.MaxVal/g
s/\b\(HScroll\|VScroll\|VSB\|HSB\)^\.Min\b/\1^.MinVal/g
s/\bD^\.GetFileName(S);/S := D^.GetFileName;/
s/if CurPos > Length(Data)-1 then/if CurPos > Length(Data^)-1 then/
