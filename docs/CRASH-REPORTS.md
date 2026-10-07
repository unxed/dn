# The log of a run and the report of a crash

DN keeps a log of every run and writes a report when it crashes (the flight recorder, `dn/src/flightrec.pas`). The aim: a fault that nobody can
reproduce comes with what is needed to find it. When a fault happens, **hand over the report (and `dn.log` / `dn_prev.log`)**: they say what DN
was, in which state and what was done in the last minutes.

## Where the files are

The directory of the settings of the user (the same as `dn.ini`):

| System | Directory |
|---|---|
| Linux, macOS, BSD | `$XDG_CONFIG_HOME/dn/`, else `~/.config/dn/` |
| Windows | `%APPDATA%\DN\` |
| DOS | the directory of the program |
| `DN2` is set | the directory that `DN2` names |

| File | What is in it |
|---|---|
| `dn.log` | the log of this run, one line per event, written at once (it survives a hang or a kill) |
| `dn_prev.log` | the log of the run before (`dn.log` is renamed at the start); a log is cut at 1 MB |
| `crash/crashNNN.txt` | a report of a crash (the last 20 are kept) |

## What is in the log

`+12.345 kind text`: the seconds after the start, the kind of the line, the text.

- `fact`: the key facts of the run: the program and the build (the commit), the system, the compiler, UTF-8 or code page inside, the directories, the
  arguments, `TERM`, `COLORTERM`, `TERM_PROGRAM`, `LANG`, `LC_ALL`, `LC_CTYPE`, `DNLNG`, `DN2`, the size of the screen.
- `key`: a key, by its name (`kbF5`, `kbCtrlQ`...) with the modifiers (`[S]` Shift, `[C]` Ctrl, `[A]` Alt) and the view that gets it (`@ TFilePanel`).
  **The typed characters are not recorded** (a password may be among them): the line says `<char>`.
- `mouse`: a click with the place and the buttons. A move of the mouse is not an event of the log.
- `cmd`: a command (`cmQuit #1`) and the view that gets it.
- `dir`: a panel changes its directory. `run`: an external program (or a command line) is started. `file`: a copy, a move, a delete starts.
- `note`, `crash`, `exit`: the notes of the program; the end of the run (`exit code 0`; `exit after a crash`). A run that did not end with the line
  `exit` was killed, hung, or crashed without a report: **the next log says so** in its first lines.

## What is in the report of a crash

The report is written first, before DN draws its fatal screen, so the screen is what the user saw.

1. the build, the time, the exception and its **call stack with the lines of the sources** (the builds for Linux and Windows have them; DOS has the
   addresses only);
2. the key facts, as above;
3. the state: the chain of the current views (the window, the dialog), both panels (the directory, the number of files, the cursor, the selection), the memory;
4. the last 300 events (the same lines as in the log);
5. **the text of the screen** at the moment of the crash.

## Privacy

The files are text, look at them before you hand them over. They contain the names of the directories (the panels, the commands that were started, the
directory of the settings) and the screen text (which may show names of files and the contents of what was open). They do not contain the characters that
were typed, unless you ask for them.

## The switches (environment variables)

| Variable | Effect |
|---|---|
| `DN_LOG_KEYS=full` | the typed characters are recorded too (for a hunt of a fault that needs them) |
| `DN_LOG=0` | no `dn.log` is written (a report of a crash is still written) |
| `DN_TEST_CRASH=1` | a test aid: the key F12 is an access violation (`tools/dn-linux-crash.py`) |

## For the one who reads a report

`dn.log` + the newest `crash/crashNNN.txt` + the line `build <commit>` of the report: check out that commit and build as usual
(`tools/build.sh`); the call stack names the lines. The names of the commands and keys come from `dn/src/evnames.pas`
(made by `tools/gen-evnames.py`).
