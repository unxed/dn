# reason: (a) the new TV. The classes of DN that were in DIALOGS.PAS and are carved into DNDlgs (dn/carve.list) are named
# `Dialogs.TFoo` in regall.pas.
s/\bDialogs\.\([PT]\(HexLine\|ParamText\|Page\|PageFrame\|Notepad\|NotepadFrame\|Bookmark\|ComboBox\)\)\b/DNDlgs.\1/g
