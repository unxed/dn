> **2026-10-04: the unit `vputils` is gone.** `Min`/`Max` are `Math` of FPC; `Int2Hex`, `Ptr2Hex` are `IntToHex`; `GetTimeMSec` is `GetTickCount64` (in `events.pas`); `GetDateDow` is `Dos.GetDate`; `GetVolumeLabel` is `SysGetVolumeLabel` (`vpsyslow`);
> `XorScramble` is in `tetris.pas`, `NameOfRec` in `lfn.pas`; the cursor and the size of the screen (`HideCursor`, `ShowCursor`, `GetCursorSize`, `SetVideoMode`) are in `compat/drivers.pas`. The list below is the history.

# VPUTILS.PAS: names used by the files that we keep

39 names are declared in the interface; 9 are used (138 uses).

| name | uses | files |
|---|---|---|
| min | 75 | advance, advance2, arc_lha, calc, cmdline, dblwnd … |
| max | 48 | advance, arvid, calc, dblwnd, diskinfo, dnutil … |
| setvideomode | 5 | videoman |
| showcursor | 3 | cmdline, flpanel, microed |
| hidecursor | 2 | cmdline, flpanel |
| int2hex | 2 | diskinfo |
| gettimemsec | 1 | events |
| getvolumelabel | 1 | filescol |
| getcursorsize | 1 | videoman |
