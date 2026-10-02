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
- GetPalette^ := X (dbview.pas and others): DN changes the palette of a view by writing into it; the assignments are dropped (edit 105), the default palettes are used.
- dpmi32.pas: `ShadowCount: Integer = 0` (an initialized variable of the unit) was 8 when the program started under DOSBox-X
  (DOS, go32v2), so DosShadow found its table full; it is set to 0 in the initialization. The cause is not understood
  (the value of another unit's static data? check that the initialized data of the exe are loaded whole).

## Added with the resource compiler (rcp) run
- Argument evaluation order: VP evaluates call arguments left to right, FPC right to left. edit 117 hoists the
  `Token(S, i)` reads of rcp.pas into temporaries. Other places of the tree may depend on the order too (look when a
  value is "shifted" at run time).
- `{$PACKRECORDS 1}` is added to STDEFINE.INC (vpc.cfg: `$AlignRec-`): the data records of the dialogs (TSysData...) must
  be byte-aligned. It also packs the `object`s of DN units (VP aligns objects by `$AlignData+`): check if it matters.
- tv `TListBoxRec` is `packed` with a LongInt `Selection` (DN: Integer, 32 bits in the Delphi mode). The Word of the
  original TV is not kept; `TvList.ListBoxOwnsList` (default True, TV) is set to False by DNApp: TListBox.Done of DN does
  not dispose the list (TSysDialog.Done does it).
