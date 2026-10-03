# PR to joncampbell123/dosbox-x: DOS_CheckExtDevice() must not loop forever

Branch: `unxed/dosbox-x` `claude/fix-extdevice-loop` (one commit on `master`, pushed). Open the PR by hand (the session cannot open a PR in a foreign repository):

https://github.com/joncampbell123/dosbox-x/compare/master...unxed:dosbox-x:claude/fix-extdevice-loop?expand=1

**Title:** DOS: stop DOS_CheckExtDevice() from looping forever on a damaged device chain

**Body:**

`DOS_CheckExtDevice()` walks the chain of device headers in guest memory with `while(1)` that ends only at `FFFF:FFFF`. If the chain is damaged, the emulator hangs: every `FindFirst` goes through `DOS_FindDevice()` and into this loop.

I hit it with DOS Navigator (a go32v2 program, CWSDPMI): after it starts, the CON header at `00F9:0000` (`DOS_CONDRV_SEG`) is zeroed (`next=0000:0000 attr=0000`), the walk goes into the interrupt table and never ends; a `gdb` backtrace of the hung emulator is `DOS_21Handler -> DOS_FindFirst -> DOS_FindDevice -> DOS_CheckExtDevice -> mem_readw`. The program then never gets its `FindFirst` answered (the emulator is busy at 100% of one core).

The patch gives up after 1024 links (more than any real chain) and returns "not an external device". With it the program runs.

I do not know yet what zeroes the header (DN, the DPMI stub or the emulator); the guard is right in any case: guest memory must not be able to hang the emulator. Tested: Linux/SDL2, headless; DN draws its panels with the patch, hangs without it (the same on unpatched `master`, `e013b8b`). Not tested: other hosts.
