# tools/: what each script does and who calls it

One table instead of reading every header. Arguments are mostly environment variables (`DN_*`, `TV_*`); the header of each script has the usage.
"CI" is the workflow of `.github/workflows/` that runs it; "by hand" means that nothing in CI calls it.

## Build

| Script | What it does | CI |
|---|---|---|
| `rename-unit.py OLD NEW` | renames a unit of DN (the file, `unit`, every `uses` and `OLD.Name`): one family of names per commit, then the build and the tests | dn |
| `build.sh TARGET` | **The one command**: builds `rcp`, the resources and `dn` from `dn/src` + `tv/src` for `linux64`, `linux`, `aarch64`, `dos`, `win64`, `win32` into `out/TARGET` (or the second argument) | dn-linux, dn-windows |
| `dn-env.sh` | sourced by the scripts: the compiler, the units, the flags of a target (`DN_TARGET`, `DN_PREFIX`) | (via the others) |
| `build-fpc-go32v2.sh` | FPC cross compiler x86_64 Linux -> DOS (go32v2) from the official sources | toolchain, tv |
| `build-fpc-i386-linux.sh` | cross compiler to 32-bit Linux | dn-linux |
| `build-fpc-aarch64-linux.sh` | cross compiler to aarch64 Linux (needs `binutils-aarch64-linux-gnu`) | dn-linux |
| `build-fpc-windows.sh` | cross compilers to win32/win64 | dn-windows |
| `gen-shim.py` | makes the "shim" units with the names of the Borland Turbo Vision units that DN uses | dn, dn-linux, dn-windows |

## Distributions (`dist/`)

| Script | What it does | CI |
|---|---|---|
| `dn-dist.sh` | `dist/dos/`: dn.exe for DOS, resources, DPMI host, licences, screenshots | by hand |
| `dn-linux-dist.sh` | `dist/linux`, `linux64`, `aarch64` with the screens of the pty tour | by hand |
| `dn-win-dist.sh` | `dist/win64`, `dist/win32` | by hand |

## Tests

| Script | What it checks | CI |
|---|---|---|
| `tv-test.sh [t_name ...]` | unit tests of `tv/tests/t_*.pas`, native or another CPU (`TV_FPC`, `TV_RUN`) | tv |
| `dn-test.sh` | unit tests of `dn/tests/t_*.pas` (`t_resload` reads the resources of `out/linux64` or `DN_RES_DIR`, else reports SKIPPED) | dn |
| `build-matrix.sh` | every shipped build configuration (linux64 UTF-8 and code page, i386, aarch64, win64/win32 both, DOS both): PASS, FAIL, or UNAVAILABLE when the toolchain is not here (never a pass); `DN_MATRIX_REQUIRE=1` fails on UNAVAILABLE | dn |
| `check-layout.sh` | the separation of `tv/`, `dn/`, `bootstrap/` (what may use what, where a `tv/src` unit comes from) | layout |
| `../bootstrap/tools/dn-manifest.py --check` | the manifest of provenance (PROVENANCE) of `dn/src` against the archive | dn |
| `dos-run.sh DIR PROG.EXE` | runs a go32v2 program in DOSBox-X without a display | tv |
| `pty_screen.py` | the library of the pty tests: runs a program in a pty, sends keys, keeps the screen (`PTY_RUN_PREFIX` for qemu) | tv, dn-linux, dn-windows |
| `accept-local.sh build\|run\|all\|shot` | the object vs class gate on this machine in one command: builds the pinned object baseline (worktree, shared fixes backported) and the class tree, runs `dn-linux-accept.py` (shards, areas), `shot` shows one build on a screen | by hand (CI: dn-accept) |
| `dn-linux-tour.py` | smoke tour of the Linux build: scenarios from a clean start, keys, the screen | dn-linux |
| `dn-linux-ops.py` | file operations of DN in a pty, checked on the file system | dn-linux |
| `dn-linux-locale.py` | the single-byte code page by the locale of the host | dn-linux |
| `dn-linux-find.py` | Find File (Alt+F7) with a mask and with a text, the result panel | dn-linux |
| `dn-linux-resize.py` | the terminal changes its size under DN (SIGWINCH: 80x25, 120x40, 100x30): the bars and the frames follow | dn-linux |
| `dn-linux-fsattrs.py` | symbolic links (to a file, to a directory, dangling) and read-only files in the panels: list, enter, F5, F8, the permissions of the copy | dn-linux |
| `dn-linux-desktop.py` | the options Autosave Desktop and Preserve directory, Alt-X, the next start: `dn.dsk` and the directory of the panel are restored (the Linux twin of the scenario `autosave` of `dn-dos-input.py`) | dn-linux |
| `dn-linux-arcmembers.py` | F8 on a member of a zip and F5 into the archive of the other panel, checked on the archive (the add needs the system `zip`) | dn-linux |
| `dn-linux-menusweep.py` | every item of the main menu, the submenus included, in the three languages, each opened from a fresh start: no fatal error (found the dialog of Alt-K and View as Hex) | by hand (`-j N`) |
| `dn-linux-kitty.py` | keys in the encoding of the Kitty keyboard protocol: a press and a release are one character, a repeat is a key, the lock bits, Ctrl-Tab, Alt-X | dn-linux |
| `dn-linux-embterm.py` | programs that read the terminal, run from the command line: a prompt and a typed line, the size of the terminal, raw mode (q, Up), Ctrl-C | dn-linux |
| `dn-linux-locale-utf8.py` | the build with UTF-8 inside under C, POSIX, KOI8-R, ru_RU.UTF-8, en_US.UTF-8 and a Latin-1 locale: names, Russian typed into the command line and a dialog | dn-linux |
| `dn-linux-clip.py` | the clipboard of DN in a pty: copy in the editor goes to the terminal by OSC 52, paste inside DN, bracketed paste into the editor and the command line, `TV_CLIPBOARD=0` | dn-linux |
| `dn-linux-names.py` | `DN_RUN_PAUSE` 0/1/2, names with spaces (enter, F7, F5, F8, checked on the file system), a missing directory (`cd`, a directory removed under the panel), a zip in a zip | dn-linux |
| `dn-linux-crash.py` | the flight recorder: the log of a run (`dn.log`, `dn_prev.log`), the report of an access violation forced with `DN_TEST_CRASH=1` + F12 (`crash/crash001.txt`), the typed characters not recorded, `DN_LOG_KEYS=full`, `DN_LOG=0`, a killed run told in the next log | dn-linux |
| `gen-evnames.py` | writes `dn/src/evnames.pas` (the names of the commands and the keys for the log) from `commands.pas`, the units of `tv/src` and `tvkeys.pas`; `--check` is in `check-layout.sh` | layout |
| `dn-linux-config.py` | where the files of the user go: `$XDG_CONFIG_HOME/dn`, `~/.config/dn`, the move of the files of an older DN (the originals stay), `DN2` | dn-linux |
| `dn-linux-archives.py` | the archive matrix (enter, F3, F4, F5, F8, add) for zip, 7z, tar, tgz, tar.gz, tar.bz2, tar.xz; `DN_ARC_ONLY='simple.zip ...'` runs some | dn-linux |
| `dn-linux-menus.py` | opens every item of every menu, reports what died | by hand |
| `dn-win-smoke.py` | the Windows build on a real console (ConPTY via pywinpty) | dn-windows |
| `dn-tour.sh` | the same tour of the DOS build in DOSBox-X | by hand |
| `dn-dos-input.py` | the DOS build in DOSBox-X on a virtual X display (Xvfb): a real X pointer through INT 33h (menu, double click, status line), a normal exit (autosave of the desktop, the saved setup) | by hand |
| `showcase-dosbox.sh` | builds and runs the DOS demo of `tv/` in DOSBox-X | by hand |
| `audit-encoding.py [--against REV]` | lost or damaged characters in the tracked text (UTF-8, U+FFFD, C1 controls) and against an older revision or the original tree | test_audit_encoding |
| `render-dump.py` | renders a text screen dump of the DOS backend into an image | tv |

## Debug and generators (not part of the build)

| Script | What it does |
|---|---|
| `dn-linux-try.py OUTDIR 'KEYS'` | runs the Linux build with keys, shows the screen and `DN.ERR`: reproducing a crash |
| `dn-trace-calls.py`, `dn-trace-init.py` | put trace calls into the routines / units of a copy of the tree |
| `asm-blocks.py` | lists the `asm` blocks of the sources (what a 64-bit build cannot take) |
| `gen-codepage.py`, `gen-width.py` | generate `tv/src/tvcp.inc` and `tv/src/tvwidth.inc` |
