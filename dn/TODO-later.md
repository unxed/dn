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

## Seen in DOSBox-X (2026-10-02), not done yet
- Running a program (edit 121, dn/new/dnrun.pas): the application stays alive, the screen goes to the text mode, COMMAND.COM runs
  the command, a key returns. Not done: the screen of the program is not kept for the user screen (Ctrl-O, Alt-F5), the
  program is not run in a window, no time information (TimerMark), the cursor and the video mode that the program left are
  not restored in all cases.
- The saved desktop (DN.DSK / swap) is not checked: the panels open at the next start only because no desktop is saved.
- DOSBox-X without a display reports Alt as pressed (BIOS flags 0040:0017 bit 3): the status line shows the Alt labels;
  DNApp clears the flags while DNKEYS drives the run (a test aid only).

## Word of VP (2026-10-02): a systemic doubt
Virtual Pascal's Word has 32 bits (the type `AWord` of DN is the 16-bit one for the file formats; the key codes
`kbAltX = $082D00` are stored in `KeyCode: Word`). FPC has 16 bits. Edit 118 fixes the key codes of the menus and the status
line (Alt-X was Ctrl-Alt-X). Everywhere else DN keeps a value above 65535 in a Word the value is silently cut (range checks are
off): look for it when something "shifted" is seen. Found so far: the key codes (edit 118, 119), the range test of the string lists (edit 120: `Key-Base < Count` wraps in VP). A global way (the type Word = LongWord in each unit, `Lo`/`Hi` of it)
is not tried: it changes the sizes of records that go to `tv/` (TCluster data, TEvent).

## The screen of DN (2026-10-02)
`Drivers.ScreenBuffer` is the 16-bit copy of the screen of tv/ (VPSysLow.SysTvGetSrcBuf), refreshed by DNApp at every idle; DN reads
it (user screen, screen savers) and writes back with SysTvShowBuf. The user screen is the text screen that was there before DN
(VPSysLow grabs it at the start). Not done: the characters above 255 / combined ones of tv/ become '?' in the copy; the copy is
converted at every idle even when nobody reads it (cheap: 2000 cells).

## Справка (tvhc/TvHelp)
- `.hlp` занимает 400-460 КБ из-за индекса: он плоский (массив позиций по номеру контекста), а в справке DN номера доходят до
  ~49000 (и `_`=65535). Хранить индекс разреженным (отсортированные пары) — формат наш, менять можно; пока не мешает.
- Формат `.htx` выведен из исходника оригинального `tvhc` (в архиве `angelbbs_DosNavigator`; он только читался, код не
  переносился) и проверен сверкой: номера тем совпадают с `dnhelp.pas` из архива для всех общих имён (в самих `.pas` из архива
  встречаются имена, которых нет в `.htx`: версии файлов разные).
- Строки справки ограничены 255 символами (`ShortString` в `GetLine`); абзац — 4095 байт (как в оригинале).
- Окно справки — 50x18 как в Borland; настройка размера — позже (вынести в настройку).

## go2dos: что нужно от хоста для UTF-8 в DOS (предложения владельцу go2dos)
- Буфер обмена: сейчас WinOldAp только OEM (`CF_TEXT`/`CF_OEMTEXT`, `docs/DOS-EXTENSIONS.md` §3). Нужен режим UTF-8 по образцу
  `DOS-UTF8/NAMES` (выбор кодировки процессом) или формат `CF_UNICODETEXT` в UTF-8.
- Экран и клавиатура: в спецификации go2dos остаются OEM; честный UTF-8 экрана и ввода — отдельное расширение (когда понадобится).
