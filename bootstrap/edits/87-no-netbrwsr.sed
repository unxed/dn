# reason: (g) the target: DOS has no Windows network browser (unit NetBrwsr, excluded). flpanel.pas only names the unit
# in its uses clause (for its initialization).
/^[ \t]*,[ \t]*netbrwsr[ \t\r]*$/d
