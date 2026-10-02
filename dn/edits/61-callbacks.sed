# reason: (a) the new TV, (д) the modern compiler. FirstThat/LastThat/ForEach take the routine that is declared
# inside the caller (Turbo Pascal: @Name); in the Delphi mode of FPC @Name is an untyped pointer, the name
# without @ is the procedure variable of the nested kind that tv/ wants (tv/DESIGN.md).
s/\.\(FirstThat\|LastThat\|ForEach\)(@\([A-Za-z_][A-Za-z_0-9]*\))/.\1(\2)/g
