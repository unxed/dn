# License of the files of `dn/`

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
