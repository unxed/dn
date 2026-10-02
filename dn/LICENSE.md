# License of the files of `dn/`

Why two licenses can live in one program: the license of DN OSP (RIT Research Labs) binds the DN code and *its versions and
derivatives* ("the licence and distribution terms for any publically available version or derivative of this code cannot be
changed", in the head of every file). It does not reach a separate file that is not derived from that code, even if the
program that is linked of both is one: the files are separate works, each under its own license. So the rule is by file:
a file that is DN code (or an edit of it, or a piece cut out of it) stays under the license of DN; a file that we wrote
without taking DN code is MIT, whatever the program does with it.

Two licenses live in `dn/src`; the file `PROVENANCE.md` says which file is under which.

1. **Our files** ("Our files" in `PROVENANCE.md`): MIT, the root file [`../LICENSE`](../LICENSE). New files added to `dn/`
   that are not derived from the code of DN are of this kind too.
2. **DOS Navigator code** (the other classes): the license in the head of each file (Dos Navigator Open Source, RIT Research
   Labs; BSD-like). Its conditions, which hold for everything we publish from these files, including the binaries:
   - the notices of copyright stay in the files (never remove or change the head of a file);
   - a binary distribution reproduces them in the documentation (`dist/*/README.TXT` and the "About" box do);
   - an advertisement or a mention of the program names "Based on Dos Navigator by RIT Research Labs";
   - the license and the terms of distribution of the code **cannot be changed**: a file derived from DN (an edit of it, a
     piece cut out of it) stays under the same license, even if the change is ours.

A change in a file of the second kind (an ordinary commit after the first one) is under the license of that file. A new file
that does not take code from DN is MIT.
