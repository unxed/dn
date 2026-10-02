#!/usr/bin/env python3
"""reason: (д) the modern compiler / (б) the target. The DPMI32 build of DN ends the application and gives the command to the
loader DN.COM (DOS), which is not part of this build: DN died ("Halt(1)") when a program was started. The branch of the other
targets keeps the application alive: this edit makes ExecStringRR of dnexec.pas run the command through DNRun.RunExternal
(dn/new) and go on with the common tail (redraw; the re-start of the video, the events and the memory is removed). usage: 121-exec-dos.py FILE...   (acts on dnexec.pas only)"""
import sys, os, re
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'dnexec.pas':
        continue
    s = open(p, 'rb').read().decode('latin-1')
    nl = '\r\n' if '\r\n' in s else '\n'
    a = s.find('  SaveDsk;' + nl + '  Application^.Done;')
    b = s.find('  Halt(1);', a)
    if a < 0 or b < 0:
        print('121-exec-dos: NOT found')
        continue
    end = b + len('  Halt(1);')
    s = s[:a] + '  SaveDsk;' + nl + '  DNRun.RunExternal(S);' + s[end:]
    # the tail started the video, the events, the memory again after the program (the other targets stop them before it): the screen
    # of TV (the buffer of the application) and the keyboard stay as they are here
    c = s.find('  InitDOSMem;', a)
    d = s.find('InitSysError;', c)
    if c > 0 and d > 0:
        s = s[:c] + '  { the screen of TV, the events and the memory are not stopped for the program: nothing to start again }' + s[d + len('InitSysError;'):]
    else:
        print('121-exec-dos: tail not found')
    # DNRun in the uses of the implementation
    m = re.search(r'^implementation[ \t]*\r?\n\s*uses', s, re.I | re.M)
    if m:
        s = s[:m.end()] + ' DNRun,' + s[m.end():]
    else:
        print('121-exec-dos: uses not found')
    open(p, 'wb').write(s.encode('latin-1'))
    print('121-exec-dos: replaced')
