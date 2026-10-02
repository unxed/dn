# Not in the first version

The first version is the original public code with a minimum of changes (PLAN.md,
decision 10). Everything else goes here: refactorings, fixes of old bugs, improvements,
doubtful places that were found on the way. Format: a line with the file, what, and why it
was not done now.

## Doubtful places found while making dn.pas compile (2026-10-02)

- stdefine.inc: the tree is evaluated with VIRTUALPASCAL defined (dn/target.env), otherwise the branch for Borland Pascal
  (BIT_16, no DualName/USELFN) is taken. FPC itself never sees VIRTUALPASCAL (the branches are stripped).
- netbrwsr.pas (Windows network browser) is excluded for the DOS target; flpanel.pas only named it (edit 87). The original
  DOS (DPMI32) configuration did not compile without it either (unit Windows).
- views.inc: TaggedDataOnly/TaggedDataCount exist but tv/ TGroup.GetData does not honour them (the "tagged controls only" data).
- tv/: TDialog.DirectLink, TScrollBar.Step/ForceScroll, TView.EnableCommands (methods) were added for DN. DN's
  TInputLine.Data is an AnsiString, in tv/ it stays PStr; the few DN sites use `Data^` (edit 89).
- Comp -> Int64 (edit 82): in VP Comp is a 64-bit integer; sizes/positions are Int64 here.
- Word is 16 bit here, 32 bit in VP (see the earlier notes): Dos.GetDate/GetTime variables of uucode.pas are Word (edit 86).
- objects2.pas is ours (dn/new): ObjChangeType assumes that the VMT link is the first pointer of an instance (true for tv/ objects).
- ExecFlags/TExecFlags (vpsyslow.pas): only the names; DN compares ExecFlags = efAsync, the value is never set.
- cellscol.pas (spreadsheet): the values of the cells are Double (8 bytes) in the files, Real48 (6 bytes) in the original
  (FPC cannot convert Real48): the spreadsheet files of the original cannot be read, ours cannot be read there (edit 92).
- wfMaxi (views.inc): the flag and the command cmMaxi (maximize a window over the desktop, DN) are not implemented in tv/ yet.
