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
| `dn-dist.sh` | `dist/dos/`: DN.EXE for DOS, resources, DPMI host, licences, screenshots | by hand |
| `dn-linux-dist.sh` | `dist/linux`, `linux64`, `aarch64` with the screens of the pty tour | by hand |
| `dn-win-dist.sh` | `dist/win64`, `dist/win32` | by hand |

## Tests

| Script | What it checks | CI |
|---|---|---|
| `tv-test.sh [t_name ...]` | unit tests of `tv/tests/t_*.pas`, native or another CPU (`TV_FPC`, `TV_RUN`) | tv |
| `dn-test.sh` | unit tests of `dn/tests/t_*.pas` | dn |
| `check-layout.sh` | the separation of `tv/`, `dn/`, `bootstrap/` (what may use what, where a `tv/src` unit comes from) | layout |
| `../bootstrap/tools/dn-manifest.py --check` | the manifest of provenance (PROVENANCE) of `dn/src` against the archive | dn |
| `dos-run.sh DIR PROG.EXE` | runs a go32v2 program in DOSBox-X without a display | tv |
| `pty_screen.py` | the library of the pty tests: runs a program in a pty, sends keys, keeps the screen (`PTY_RUN_PREFIX` for qemu) | tv, dn-linux, dn-windows |
| `dn-linux-tour.py` | smoke tour of the Linux build: scenarios from a clean start, keys, the screen | dn-linux |
| `dn-linux-ops.py` | file operations of DN in a pty, checked on the file system | dn-linux |
| `dn-linux-locale.py` | the single-byte code page by the locale of the host | dn-linux |
| `dn-linux-menus.py` | opens every item of every menu, reports what died | by hand |
| `dn-win-smoke.py` | the Windows build on a real console (ConPTY via pywinpty) | dn-windows |
| `dn-tour.sh` | the same tour of the DOS build in DOSBox-X | by hand |
| `showcase-dosbox.sh` | builds and runs the DOS demo of `tv/` in DOSBox-X | by hand |
| `render-dump.py` | renders a text screen dump of the DOS backend into an image | tv |

## Debug and generators (not part of the build)

| Script | What it does |
|---|---|
| `dn-linux-try.py OUTDIR 'KEYS'` | runs the Linux build with keys, shows the screen and `DN.ERR`: reproducing a crash |
| `dn-trace-calls.py`, `dn-trace-init.py` | put trace calls into the routines / units of a copy of the tree |
| `asm-blocks.py` | lists the `asm` blocks of the sources (what a 64-bit build cannot take) |
| `gen-codepage.py`, `gen-width.py` | generate `tv/src/tvcp.inc` and `tv/src/tvwidth.inc` |
