# How DOS Navigator was modernized: a guide to doing it again from scratch

For a programmer who has to repeat the whole way (an old DOS file manager in Pascal → Free Pascal, Linux, Windows, UTF-8, an embedded
terminal) without this repository in hand. It holds what took us the most time to find out. It is written as a path: do the steps in this order,
check each one before the next, and read the traps at the end of each part before you start it.

Nothing here replaces judgment. When a step does not give the result that is written here, stop and find out why; do not go on by guessing.

---

## 0. The task and the result

**Start:** DN OSP 2.14 (Dos Navigator Open Source, RIT Research Labs and contributors): ~170 Pascal files for Virtual Pascal / Borland Pascal,
one-byte strings in the DOS code page 866, Turbo Vision (the Borland one) as the UI library, DOS and 16-bit assumptions all over.

**Result we have:** the same program built by one command with Free Pascal 3.2.x for Linux (x86_64, i386 static), Windows (win32, win64), DOS (go32v2),
with UTF-8 inside on Linux and Windows, a terminal backend (no ncurses), a clipboard, a Windows console backend, and an embedded terminal for the
commands. Everything is checked by CI on every push.

**Two rules came first and shaped everything:**

1. **Licensing was a requirement, not a detail.** The program must be free to publish. The Borland Turbo Vision source is not. So: the UI library
   (`tv/`) is a translation of the *open* C++ port `magiblot/tvision` (MIT + the Borland disclaimer) into Pascal; the DN code is only what the public DN OSP
   archive gives, minus the files whose code comes from Borland; our own new code is MIT. We built a detector (the *audit*, section 3) that compares our
   sources with the Borland sources token by token, and made it a gate of CI. If you do not have this constraint you can skip section 3, but then you
   still have to decide which library you build on.
2. **A reproducible path from the public archive to our tree.** The repository does not hold the archive; it holds the address and the sha256 of it
   and a script that turns it into our first commit (`bootstrap/`). After the first commit the tree is edited as usual. This is a record, not a
   daily tool; but it is also the best documentation of *what had to be changed* (read `bootstrap/edits/` first: it is the list of the incompatibilities).

---

## 1. The order of work (and why this order)

Each step must give something you can run before you start the next one.

| # | Step | You can run |
|---|---|---|
| 1 | Toolchain and CI: FPC 3.2.2 native + cross compilers built from source | a hello world for every target in CI |
| 2 | Tests first: unit tests with a tiny harness (`Check(cond, name)`, "ALL OK" at the end) and a pty-based test for the terminal | `tools/tv-test.sh` |
| 3 | The UI library `tv/` (translation of magiblot/tvision), screen in memory, tested without a terminal | unit tests |
| 4 | The terminal backend (Linux): raw input parser, ANSI output, mouse, clipboard | a demo in a pty, a screen emulator for the test |
| 5 | The DN tree: fetch, cut out the Borland parts, edit mechanically, replace the excluded units with our own | it compiles |
| 6 | The system layer of DN (`vpsyslow`): files, drives, time, keys, running programs | DN starts and shows panels |
| 7 | Resources (dialogs/strings are compiled by DN's own `rcp` tool) and the help (the help compiler `tvhc`) | menus and F1 work |
| 8 | Regression tests of real work in a pty: F5/F6/F7/F8, editor, viewer | `tools/dn-linux-ops.py` |
| 9 | Windows (console API), DOS (DOSBox-X in CI) | CI smoke tests |
| 10 | UTF-8 inside (the hard one: section 6) | names, editor, clipboard in any alphabet |
| 11 | Embedded terminal (section 8) | commands run in DN's screen |

The temptation is to start with DN. Do not: DN is 170 files that fail in a hundred ways at once. With a tested UI library and a tested terminal
backend, every failure in DN is a failure in DN.

---

## 2. Toolchain

* **Free Pascal 3.2.2** is enough for everything (Debian/Ubuntu: `fp-compiler fp-units-rtl`). Use `-Mdelphi` for the DN tree (it is Delphi-flavoured: `String` is
  `AnsiString` with `{$H+}`), `-Mobjfpc` and `{$H-}` for `tv/` (the Borland `object` types, ShortString by default).
* **Cross compilers are built from the FPC sources** (no packages exist for them): `go32v2` (DOS), `i386-linux` (static, runs on a 64-bit kernel and needs
  no libc), `win32` and `win64` (need `binutils-mingw-w64-*` for the assembler/linker). Each is a script of ~40 lines: `make crossall CROSSOPT=...` then
  `make crossinstall`. They take 10–25 minutes: cache the result in CI by the hash of the script.
* **One command to build:** `tools/build.sh TARGET [OUTDIR]` (`linux64|linux|dos|win64|win32`). It generates unit *shims* (below), compiles `rcp` (the resource
  compiler) and `dn`, runs `rcp` to make `*.LNG/*.DLG`, runs the help compiler for `*.HLP`. Keep all target differences in one env file (`tools/dn-env.sh`).
* **Object files go to a separate directory per option set.** FPC does *not* rebuild a unit when only a `-d` define changed; a build of the same tree with a
  different define silently mixes units. We had a day lost on a "heisenbug" that was a stale `.ppu`. One obj directory per (target, defines). Also never
  compile in the source directories: a stray `.o` in the tree once got into our provenance manifest and broke CI (`tools/tv-test.sh` and
  `tools/dn-test.sh` build into `build/`).
* **DOS is tested under DOSBox-X** (`dosbox-x -silent -nogui -defaultconf -c "mount c ..."`), with `CWSDPMI.EXE` as the DPMI host. It is slow and the
  DOS tests are the first to be flaky: keep them few and make them print the screen as text (we dump video memory from the program itself).
* **Wine is not a test platform for the console.** The Windows console of Wine draws bright backgrounds unevenly. We test Windows only on `windows-latest`
  in GitHub Actions through ConPTY (`pywinpty`), reading the screen with the same emulator as for Linux.
* **GitHub Actions YAML:** a step name that contains `: ` (colon + space) makes the whole workflow invalid, and GitHub then shows a run with *zero jobs* and
  no error. It happened to us twice. Validate with `python3 -c "import yaml; yaml.safe_load(open(f))"` before pushing.

---

## 3. The audit (only if you have the licensing constraint)

* Take the Borland sources (you must have them legally; keep them outside the repository and never show them to the person/tool that writes code).
* Tokenize both trees (identifiers and punctuation; ignore case, comments, whitespace). For each of our files compute: `raw%` (share of tokens that are in a
  matching run) and `maxrun` (the longest run of matching tokens). Gates we used: for DN, `raw% ≤ 2` and `maxrun < 48`; for `tv/`, matches are natural (same
  author's architecture), so only procedures that cite their source in the unit header are allowed.
* Files above the gate are **excluded** (`bootstrap/exclude.list`, every entry has a reason) and replaced by our own unit with the same interface, or the
  matching procedure is **rewritten from a behavior specification** (never from the Borland text). The unit headers of `tv/` name the magiblot files and the commit
  that each unit was translated from.
* `tools/check-layout.sh` keeps the two projects apart: `tv/` must not mention DN or use its units; every `tv/` unit has an origin note ("Translated
  from…" or "MIT"); `dn/PROVENANCE.md` (class of every file: ours / carved / RIT / contributor / upstream without notice) must be up to date
  (`python3 bootstrap/tools/dn-manifest.py --check`).

---

## 4. The UI library `tv/`

Decisions that paid off:

* **Keep the Pascal TV API** (`object`, `New(P, Init(...))`, `HandleEvent`, `cm*`, `kb*`) because DN is written against it. The implementation follows magiblot's C++.
* **The cell is the unit of the screen:** `TScreenCell` = up to 15 bytes of UTF-8 + flags (wide, wide trail, overflow) + attribute (fg/bg/style; default, 16-color,
  256-color, 24-bit). All-zero bytes is a valid empty cell. Wide characters are a lead cell plus a trail cell. Combining marks are appended to the cell of their
  letter. Everything else (views, drawing buffers, the terminal output) is built on it.
* **Strings are UTF-8, but a byte string that is not valid UTF-8 is taken as characters of a code page** (a *setting*: 866 by default, or the one that goes with the locale,
  tables in `tvcodepg`). This is what let DN's one-byte strings run unchanged for a long time.
* **Backends are hooks** (`OnPollEvent`, `OnSetVideoMode`, `OnScreenWrite`, caret hooks in `TvSys`/`TvScreen`); a memory backend serves tests, `TvUnix`/`TvTermOs`
  serve terminals, `TvDos` serves DOS video memory.
* **Terminal output** is a diff against what is shown (`Shown` array of cells) and then ANSI: cursor moves, SGR (colors by the capability: `TV_COLORS=0|8|16|256|direct`),
  alternate screen, no autowrap (`?7l`). Do not use ncurses.
* **Terminal input** is the hard part, and it is all in `TvTermIO`: a byte parser for CSI/SS3 sequences, xterm "modifyOtherKeys"/kitty-style `CSI u`, bracketed paste,
  SGR mouse, with a timeout for the lone Esc (`ESCDELAY`). Known facts:
  * A terminal sends **no double-Alt** and no key-up events. DN's "quick search by double Alt" cannot work; we added Ctrl-S.
  * Ctrl+letter arrives as the control character (`$13`) with the Ctrl state, whereas DN's `kbCtrlS` constants are *scan code + char* (`$041F13`). DN's own
    `DNKeyCode` must add the scan code for Ctrl+letter, or every Ctrl-letter hotkey of DN is dead on a terminal (found late).
  * Alt+letter is `ESC letter` (UTF-8 for non-Latin letters): the program must read it as "Alt + character", not as a character of the code page.
  * A character outside the one-byte code page arrives with `KeyCode = 0` and the UTF-8 text in the event: if any layer drops events with `KeyCode = 0`, the
    character is lost silently (DN's main loop did).
* **Clipboard:** one hook pair (`ClipboardSetText/GetText`). On Linux a terminal gets OSC 52 (`ESC ] 52 ; c ; base64 BEL`; not on the Linux console; some terminals ask the user); on
  Windows `CF_UNICODETEXT`. DOS/OEM conversion is needed *only* on DOS; Windows and Linux are Unicode: only UTF-8 ↔ UTF-16 transport.
* **Test the terminal with a pty and a small screen emulator written in Python** (`tools/pty_screen.py`): it runs the program in a pty of a given size, feeds the output into an
  emulator (cursor moves, SGR, alternate screen) and lets the test read cells and attributes. 90% of our terminal bugs were found this way, in seconds.

---

## 5. The DN tree: what to expect

* **Encoding:** the files are CP866 with CRLF (and some files with mixed line endings). Editing with a normal editor or a Python text mode destroys them. Edit with scripts that
  work on bytes (`open(p,'rb').read().decode('latin-1')`, replace, encode back) and anchor on ASCII text only. Check `git diff` for "whole file changed".
* **Excluded-and-replaced units:** the Borland UI units, the Virtual Pascal runtime (`VPSYSD32` etc.). The replacements are: `tv/` for the UI; `vpsyslow` (ours) for the system layer; our
  `drivers`, `memory`, `messages`, `dnapp`, `dnstddlg`... with the *same names and procedure signatures* the rest of DN uses. First write a list of what DN actually imports from each
  excluded unit (`bootstrap/tools/dn-reach.py`), implement exactly that, nothing more.
* **Unit shims:** DN says `uses Views, Objects, App;` — those names are Borland's. We generate small units named like them that `re-export` our `tv/` units (a map
  file `dn/compat/shims/shims.map`, a generator `tools/gen-shim.py`). **Trap:** name resolution through a shim picks the *first* unit in the `uses` list that has the identifier: a function
  that exists in two units (our `GetAltChar` in `TvUtil` and in `Drivers`) silently binds to the wrong one. Qualify (`Drivers.GetAltChar`).
* **VP vs FPC differences that cost us time:** `Word` is 32 bits in VP and 16 in FPC (everything with `Word` that holds a size or an offset); evaluation order of arguments;
  32-bit inline assembler blocks (rewritten in Pascal, `tools/asm-blocks.py` lists them); `inline` on standalone functions; sets with more than 256 values; `FormatStr` parameter slots
  are `PtrInt`; file names in lower case on a case-sensitive file system (`DN` asks for `DN.INI` and `dnresource.LNG`: copy the files under the names DN asks for).
* **Drive letters and paths:** DN thinks in `C:\path`. We kept it: on Linux `C:` is the root of the file system and `/` ↔ `\` is converted at the border (`SysOsPath`, `vpsyslow`); extra drives
  (`TEMP:`, home, mounts) are listed by the system layer. Do not change DN's model; adapt at the border.
* **Resources and help are compiled by tools in the tree** (`rcp`, from `RESOURCE/*.dn?`; the help compiler). They must be built *by the host compiler* (they run during the build), also when the target is
  Windows or DOS.
* **Known time sinks:** the "tree" window scanning `/` (made stoppable with Esc); `GetKeyEvent` being a stub made every loop that waits for Esc hang; the copy buffer being 64K because of `Word`; the first
  start failing with "Error in country setup" because the XLT code page tables must be next to the program.

---

## 6. UTF-8 inside DN (the hardest part)

DN's code works on one byte per column everywhere: strings, draw buffers (arrays of 16-bit words: char + attribute), the editor (one byte per column), `Length` as width, tables of letters (case, sort).
We tried "convert at the border" first (UTF-8 names ↔ CP866 bytes in the file layer): it works for Russian and loses everything else. The final solution has these parts; do them in this order, each
with tests, each as a build option (`-dDNUTF8`) that can be turned off until the end:

1. **Draw buffers are arrays of `TScreenCell`** (not words). One mechanical change over ~30 files, and then one-byte legacy code that still writes words goes through `LegacyText` (UTF-8 → code
   page). **Trap:** after such a conversion, any call that still passes a cell array to the word-based writer (`WriteLineW`) draws garbage; the symptom showed up only on the *partial redraw* after a cursor
   move (two lines in the other panel became `♂ ◘`). Grep for every `WriteLineW/WriteBufW` whose buffer type changed, and test the redraw of two lines, not only the first full draw.
2. **Width = columns, not bytes.** Where DN cuts, pads or centers a name, it uses `Length`. We use the **proxy technique**: convert the UTF-8 string to a string with one byte per column (`#$80+i` for each
   distinct non-ASCII character, table of the characters on the side; a wide (CJK) character is two bytes, the second is `#$FF`; a combining mark lives in the entry of its letter), call the old
   column-based routine unchanged, convert back. The routine `Copy`/`Pad`/`Center` then keeps working. A wide character cut in the middle becomes a blank.
3. **Case and sort of names:** DN's `UpCase`/tables are for CP866. Add `CpUpper/CpLower` by code point (Latin-1, Greek, Cyrillic) and use them for sorting and for matching.
4. **Resources and help in UTF-8:** `iconv -f cp866 -t utf-8` the language sources during the build (not in the repository), and the help compiler counts the width of boxes in columns.
5. **Hot letters** (Alt+letter in menus and dialogs, `~F~ile`): compare the typed character (UTF-8 text from the event) with the hot letter as code points, case-insensitive, instead of comparing code page bytes.
6. **The editor** (one byte per column, the code is 10,000 lines): do *not* rewrite it. Give each document a **table**: internal bytes 128..255 stand for characters; the table starts as the code page (so a Cyrillic letter
   has the byte it always had and all of DN's tables fit), and the characters that the page does not have take free cells of the *frame characters* block ($B0..$DF) that the document does not use. The file on disk stays
   UTF-8; conversion happens at load/save, at clipboard copy/paste, in search/replace (the search string is converted to the internal form), in the case-change of a block (tables derived from the table of the
   document). A typed character that is not in the table gets a free cell (never one that the text uses: mark used cells at load and at typing/paste). When the table is full, the file is opened as a legacy file. Files that are
   not valid UTF-8 take the old path (the key map translates, internal bytes = code page bytes).
7. **Quick search, Alt+letters, input lines:** everything that takes a character from the keyboard must take the UTF-8 text of the event, convert to the internal form and append/delete *by character* (`Utf8DeleteLast`).
8. **Windows file names:** FPC's RTL uses the ANSI API for names unless told otherwise. Three calls at the start of the program make the RTL treat `string` as UTF-8 and use the wide API:
   `SetMultiByteConversionCodePage(CP_UTF8); SetMultiByteFileSystemCodePage(CP_UTF8); SetMultiByteRTLFileSystemCodePage(CP_UTF8)`. Test with names that are outside the ANSI code page of the CI machine
   (Greek and Cyrillic on an English runner).
9. **Only after all of the above** switch the default (we did Linux first, Windows after its CI test). Keep the old mode behind an option (`DN_UTF8=0`) for a while; DOS stays on the code page forever.

---

## 7. Windows backend

* The console API path is the default (`WriteConsoleOutputW` with an own interpreter of the VT subset that TvAnsi writes, so the same cell diff code serves both); the VT-sequence path is an option
  (`DN_WIN_OUTPUT=vt`) for Windows Terminal. Console API works in old consoles and in Wine; VT needs Windows 10 1809+.
* Input: `ReadConsoleInput` records are translated into the same byte sequences that the Unix parser reads; one parser, two sources.
* In Wine, bright backgrounds are drawn unevenly: draw them without the intensity bit (`DN_WIN_BRIGHT_BG`).

---

## 8. The embedded terminal (commands run inside DN)

Done in four independent units, each with its own tests (a plan from reading `magiblot/tvterm`, which uses the C library libvterm; we wrote a Pascal emulator so that the build needs only `fpc`):

1. **`TvVt`** — the emulator with no input/output: `Feed(bytes)` → a grid of cells, cursor, modes, history, answers to queries (`TakeReply`: DA, DSR/CPR, window size). Parser states: ground (UTF-8 decoder with
   overlong/surrogate checks), ESC, CSI (params with `;` and `:`, private markers `? > < =`, intermediates), OSC (BEL or ST terminated, titles, OSC 52), DCS/APC ignored to ST. Screen operations: scroll
   region, insert/delete lines and characters, erase with the background of the pen, tab stops, DEC line drawing, save/restore cursor, alternate screen (1049 saves the cursor and clears), pending-wrap flag
   (the cursor stays on the last column until the next character), wide/combining characters, `REP`. 76 tests; write the test *before* each feature from the xterm documentation.
   **Common mistakes:** a one-byte move of rows with dynamic arrays shares references (replace the row object after shifting); `DL` must not push lines to the history, `SU` and linefeed at the bottom do.
2. **`TvPty`** — a pty without libc: open `/dev/ptmx`, unlock (`TIOCSPTLCK`), read the number (`TIOCGPTN`), open `/dev/pts/N` in the child after `fork`, `setsid`, `TIOCSCTTY`, `dup2` to 0/1/2, `chdir`,
   `execve` with `TERM=xterm-256color`. The parent sets the master non-blocking. Make the argument and environment arrays *before* the fork (nothing but system calls in the child).
3. **`TvVtKeys`** — bytes for a key (cursor keys with modifiers `CSI 1;m A`, application cursor mode `SS3 A`, F-keys, Alt = ESC prefix, Ctrl+letter) and for a mouse event (X10, UTF-8, SGR 1006, urxvt 1015),
   and bracketed paste. Pure functions, easy to test exhaustively.
4. **`TvVtView`** (a TView in a window) and **`TvVtRun`** (a program on the whole screen of the application, the emulator survives the program: that is the "user screen"). The DN glue is ~30 lines
   (`dnrun.pas`: run `/bin/sh -c cmd` through `VtRunScreen`; Ctrl-O shows the screen again). Setting `DN_EMBED_TERM=0` returns to the old way; `DN_RUN_PAUSE` chooses whether to wait for Enter.

---

## 9. Testing practice

* **Three layers:** unit tests (no terminal, a tiny harness, run in CI natively and under DOS), pty tests (a real terminal session with a screen emulator), and *operation* tests of DN in a pty (copy a 3 MB file byte by byte, move,
  delete, make a directory with a Russian name, edit and save, a command from the command line). A regression found by hand must become a test in the same commit.
* **Compare the screen as text** and avoid timing assumptions: `wait_for(text)` with a timeout, not `sleep`.
* **Debugging method that worked:** (1) write down the symptoms, (2) list all possible causes, (3) strike out every cause that contradicts one symptom, (4) when the list has two items, bisect: `git worktree add /tmp/bis <commit>`,
  build with a separate object directory, run the same script. We found a regression of 40 commits in 4 builds this way.
* **Logs must be small.** Print only what is significant; a huge log cannot be given to anyone (or any tool) for analysis.

---

## 10. A list of traps (read before each step)

1. Stale `.ppu` after a `-d` change (separate object directories).
2. Files edited as text lose their encoding or line endings (edit bytes; look at `git diff --stat`).
3. YAML step names with `: `.
4. A name that exists in two units resolved through a shim to the wrong one.
5. `WriteLineW` vs `WriteLineC` after changing the type of a buffer; test the partial redraw.
6. `KeyCode = 0` events dropped; a command-lookup table with an unused slot `C1 = 0` that matches key code 0 (typing a Greek letter deleted a line before we found it).
7. Ctrl+letter constants with and without the scan code.
8. `String` in a unit without `{$H+}` is a ShortString (255 bytes): a table of 127 entries of 8 bytes does not fit.
9. Dynamic arrays are references: `A[i] := A[j]` shares the row.
10. Build artifacts in source directories corrupt generated manifests.
11. Wine is not the Windows console.
12. A long wait in a script (`sleep 60`, `until` loops) is blocked or times out in many agent sandboxes: run long jobs in the background and poll their output file.
13. A test that needs the system clipboard, a display, or Wine will not run in CI: make a hook, test the hook.
14. "Press Enter" prompts, `Writeln` to stdout while the screen is in the alternate screen, and other text output of the old DOS code: they are written into the raw terminal. Find them (`Writeln`/`Write` in DN sources) and
    route them through the screen or remove them.

---

## 11. Working agreements that kept the project moving

* Small atomic steps, each with tests and a note in the docs (so that another person can continue from the repository alone), each pushed. Iterations in the style of RUP: a usable result early, then
  improve. After each big step, **one step of refactoring** of the most burning thing (names of files, `IFDEF` sprawl, buffer models), without changing behavior.
* Doubtful choices become **settings** (`DN_UTF8`, `DN_EMBED_TERM`, `DN_RUN_PAUSE`, `DN_WIN_OUTPUT`, `TV_COLORS`, `TV_MOUSE`, `DN_CODEPAGE`) instead of arguments; a note in the TODO file records what is known to be wrong.
* No perfectionism: when you find an unrelated defect, write it in the TODO file and go back to the task.
* When information is missing (a file, a log, a sample of data), stop and ask for it with a patch or an instruction for collecting it; do not guess.
