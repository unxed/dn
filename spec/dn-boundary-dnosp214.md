# Граница между чистым кодом DN и тем, что заменяет TV

Создано `tools/dn-deps.py audit/reports/2026-10-01/dnosp214.txt` по дереву DN OSP (только имена). Файлы, не прошедшие ворота: 37 из 203.
Для каждого из них — имена, которые он объявляет и которые используют прошедшие файлы.

## views.pas — 119 имён, 3293 употреблений

at (380/48), delete (281/71), message (234/43), drawview (211/27), clearevent (127/30), close (112/38), getcolor (93/17), getstate (89/19), prev (78/10), ppalette (73/13), getextent (69/18), redraw (68/22), foreach (67/23), putevent (66/13), writeline (60/19), sfvisible (51/13), endmodal (46/6), resetcursor (41/2), sizelimits (40/1), hide (38/13), select (38/18), sfactive (36/15), sfselected (34/11), grow (32/10), makelocal (32/12), getpeerviewptr (30/11), putpeerviewptr (30/11), firstthat (29/14), enablecommands (29/12), locate (28/9), getbounds (26/11), tdrawbuffer (25/15), selectnext (24/11), mouseevent (23/10), disablecommands (22/12), gfgrowhix (22/11), lock (21/10), unlock (20/9), setrange (19/9), gfgrowhiy (19/11), focus (18/6), setparams (17/7), sffocused (17/7), mouseinview (17/10), setbounds (16/6), writebuf (15/7), makeglobal (15/9), sbvertical (14/7), standardscrollbar (13/6), sfdragging (12/6), makefirst (12/7), getsubviewptr (12/5), putsubviewptr (12/5), growto (12/5), commandenabled (12/3), registertobackground (11/6), sbhandlekeyboard (11/5), topview (11/5), pvideobuf (11/1), hidecursor (10/7) …

## _defines.pas — 73 имён, 2666 употреблений

trect (400/51), pstring (259/50), move (237/76), stok (226/49), assign (186/46), tstreamrec (183/5), tpoint (181/27), mfokbutton (145/39), mferror (109/36), ppalette (73/13), sfvisible (51/13), txlat (46/11), plongstring (44/9), sfactive (36/15), sfselected (34/11), grow (32/10), stcreate (31/16), mfyesbutton (26/15), mfnobutton (23/12), mfinformation (23/11), gfgrowhix (22/11), mfwarning (19/11), gfgrowhiy (19/11), mfconfirmation (17/10), mfcancelbutton (17/11), sffocused (17/7), sbvertical (14/7), psitem (13/4), sfdragging (12/6), sbhandlekeyboard (11/5), tphase (11/1), pvideobuf (11/1), str8 (9/4), bfnormal (9/4), bfdefault (8/7), gfgrowloy (7/6), mfallbutton (7/5), tcommandset (7/3), mfquery (6/4), str12 (6/4), bfbroadcast (6/3), sbhorizontal (5/3), pawordarray (5/3), sfdisabled (5/2), sfexposed (5/2), equalsxy (4/3), sfmodal (4/2), sfshadow (4/3), mf2yesbutton (3/3), contains (3/2), tcharset (3/2), str2 (3/1), str6 (3/1), mfsyserror (2/1), wfmaxi (2/2), fmdeny (2/2), dmdragmove (2/2), mfappendbutton (2/2), str4 (2/2), equals (1/1) …

## _views.pas — 77 имён, 2212 употреблений

delete (281/71), drawview (211/27), clearevent (127/30), close (112/38), getcolor (93/17), getstate (89/19), prev (78/10), getextent (69/18), redraw (68/22), foreach (67/23), putevent (66/13), writeline (60/19), endmodal (46/6), resetcursor (41/2), sizelimits (40/1), hide (38/13), select (38/18), makelocal (32/12), getpeerviewptr (30/11), putpeerviewptr (30/11), firstthat (29/14), enablecommands (29/12), locate (28/9), getbounds (26/11), selectnext (24/11), mouseevent (23/10), disablecommands (22/12), lock (21/10), unlock (20/9), setrange (19/9), focus (18/6), setparams (17/7), mouseinview (17/10), setbounds (16/6), writebuf (15/7), makeglobal (15/9), standardscrollbar (13/6), makefirst (12/7), getsubviewptr (12/5), putsubviewptr (12/5), growto (12/5), commandenabled (12/3), topview (11/5), hidecursor (10/7), showcursor (8/6), normalcursor (8/6), keyevent (8/4), setcurrent (7/4), setcursor (7/5), setstep (6/4), blockcursor (6/4), setcommands (6/3), menuenabled (6/3), insertbefore (6/3), freebuffer (5/3), getbuffer (5/3), dragview (5/3), getcommands (5/3), moveto (5/3), gettitle (5/1) …

## defines.pas — 28 имён, 1470 употреблений

trect (400/51), pstring (259/50), move (237/76), assign (186/46), tpoint (181/27), txlat (46/11), plongstring (44/9), grow (32/10), tawordarray (20/4), fnamestr (13/4), str8 (9/4), str12 (6/4), pawordarray (5/3), equalsxy (4/3), contains (3/2), longrec (3/2), tcharset (3/2), str2 (3/1), str6 (3/1), beep (2/2), pxlat (2/2), asciiz (2/1), str4 (2/2), equals (1/1), maxbytes (1/1), str50 (1/1), str40 (1/1), ppoint (1/1)

## collect.pas — 20 имён, 1070 употреблений

at (380/48), delete (281/71), atinsert (78/28), foreach (67/23), atfree (55/23), deleteall (33/14), sort (32/8), firstthat (29/14), atdelete (19/10), freeall (18/12), setlimit (18/9), pack (16/9), atput (13/8), atreplace (9/7), lastthat (6/3), keyof (4/1), pdircol (4/3), tstringlist (4/2), pstringlist (3/2), pitemlist (1/1)

## _collect.pas — 16 имён, 1058 употреблений

at (380/48), delete (281/71), atinsert (78/28), foreach (67/23), atfree (55/23), deleteall (33/14), sort (32/8), firstthat (29/14), atdelete (19/10), freeall (18/12), setlimit (18/9), pack (16/9), atput (13/8), atreplace (9/7), lastthat (6/3), keyof (4/1)

## messages.pas — 30 имён, 794 употреблений

messagebox (171/43), mfokbutton (145/39), mferror (109/36), idx (80/11), msg (63/22), mfyesbutton (26/15), mfnobutton (23/12), mfinformation (23/11), inputbox (22/13), mfwarning (19/11), mfconfirmation (17/10), mfcancelbutton (17/11), errmsg (14/8), biginputbox (7/5), mfallbutton (7/5), cantwrite (6/5), mfquery (6/4), messagebox2 (5/3), messageboxrect (5/3), msg2 (4/2), messagebox2rect (4/2), inputboxrect (4/2), addbutton (4/1), mf2yesbutton (3/3), msghelpctx (3/2), mfsyserror (2/1), mfappendbutton (2/2), mfabout (1/1), fmtstr (1/1), mfnextdbutton (1/1)

## tvhc.pas — 2 имён, 792 употреблений

count (788/63), keyof (4/1)

## streams.pas — 20 имён, 755 употреблений

stok (226/49), tstreamrec (183/5), close (112/38), eof (95/27), stcreate (31/16), readstrv (21/11), open (12/6), flush (12/3), registertype (10/5), writelongstr (9/3), copyfrom (8/4), readlongstr (7/3), reregistertype (6/3), readlongstrv (5/3), doopen (5/2), strread (4/2), strwrite (4/2), fmdeny (2/2), readblock (2/1), pstreamrec (1/1)

## dnstddlg.pas — 17 имён, 700 употреблений

sr (559/30), select (38/18), newlist (25/11), fdhelpbutton (15/6), fdokbutton (14/6), getfilenamedialog (13/7), getfilenamemenu (6/4), tsortedlistbox (4/2), fdopenbutton (4/4), contains (3/2), pfiledialog (3/1), tfileinputline (3/1), tfilecollection (3/1), tfilelist (3/1), tfileinfopane (3/1), tfiledialog (3/1), cmfileopen (1/1)

## helpkern.pas — 7 имён, 689 употреблений

delta (643/23), grow (32/10), position (4/1), thelptopic (3/1), thelpindex (3/1), phelpfile (2/1), numlines (2/2)

## dialogs.pas — 37 имён, 624 употреблений

mark (382/13), row (83/3), newlist (25/11), psitem (13/4), bfnormal (9/4), bfdefault (8/7), makedefault (8/3), newsitem (7/4), setvalidator (7/5), bfbroadcast (6/3), setbuttonstate (5/3), plonginputline (4/2), tlonginputline (4/2), canscroll (4/2), drawstate (4/2), buttonstate (4/2), drawbox (4/2), drawmultibox (4/2), historywidth (4/2), multimark (4/1), pnotepad (4/1), savestate (3/1), thexline (3/1), tnotepad (3/1), tpage (3/1), tbookmark (3/1), tpageframe (3/1), tnotepadframe (3/1), ppage (2/1), initviewer (1/1), inithistorywindow (1/1), recordhistory (1/1), ccluster (1/1), phexline (1/1), newpage (1/1), bfleftjust (1/1), bfgrabfocus (1/1)

## _dialogs.pas — 19 имён, 500 употреблений

mark (382/13), newlist (25/11), setrange (19/9), setlimit (18/9), makedefault (8/3), setvalidator (7/5), setbuttonstate (5/3), canscroll (4/2), drawstate (4/2), buttonstate (4/2), drawbox (4/2), drawmultibox (4/2), historywidth (4/2), multimark (4/1), focusitemnum (3/1), scrolldraw (2/1), initviewer (1/1), inithistorywindow (1/1), recordhistory (1/1)

## dnapp.pas — 34 имён, 492 употреблений

redraw (68/22), execresource (67/26), globalmessage (67/25), putevent (66/13), loadresource (35/20), writemsg (31/18), insertwindow (19/8), validview (16/9), updatewriteview (15/10), adjusttodesktopsize (10/4), globalmessagel (10/8), cascade (8/2), tile (8/2), togglecommandline (7/4), activateview (6/3), systemcolors (5/3), viewpresent (5/3), showuserscreen (5/3), setscreenmode (5/3), globalevent (5/3), forcewriteshow (5/3), run (4/2), canmovefocus (4/2), executedialog (4/2), initscreen (3/1), insertidler (2/1), ccolor (2/1), whenshow (2/1), gettilerect (2/1), openresource (2/1), twritewin (1/1), initbackground (1/1), tileerror (1/1), insertavidlern (1/1)

## colorsel.pas — 14 имён, 417 употреблений

mark (382/13), width (7/3), tcolorselector (3/1), tmonoselector (3/1), tcolordisplay (3/1), tcolorgrouplist (3/1), tcoloritemlist (3/1), tcolordialog (3/1), t_bwselector (3/1), pcolorgroup (2/1), pcoloritem (2/1), pcolordialog (1/1), colorgroup (1/1), coloritem (1/1)

## _streams.pas — 13 имён, 296 употреблений

close (112/38), eof (95/27), readstrv (21/11), open (12/6), flush (12/3), writelongstr (9/3), copyfrom (8/4), readlongstr (7/3), readlongstrv (5/3), doopen (5/2), strread (4/2), strwrite (4/2), readblock (2/1)

## _apps.pas — 15 имён, 88 употреблений

insertwindow (19/8), validview (16/9), cascade (8/2), tile (8/2), activateview (6/3), showuserscreen (5/3), setscreenmode (5/3), run (4/2), canmovefocus (4/2), executedialog (4/2), initscreen (3/1), whenshow (2/1), gettilerect (2/1), initbackground (1/1), tileerror (1/1)

## validate.pas — 5 имён, 67 употреблений

isvalid (58/11), tfiltervalidator (3/1), trangevalidator (3/1), pfiltervalidator (2/2), prangevalidator (1/1)

## memory.pas — 6 имён, 56 употреблений

lowmemory (20/12), memalloc (14/7), donememory (7/6), donedosmem (5/4), initdosmem (5/4), initmemory (5/4)

## fviewer.pas — 11 имён, 55 употреблений

searchfilestr (13/6), searchstring (11/3), chars (9/1), pfilewindow (5/3), tfilewindow (5/3), tqfileviewer (3/1), tdfileviewer (3/1), tviewinfo (3/1), pqfileviewer (1/1), pdfileviewer (1/1), pnfileviewer (1/1)

## histlist.pas — 8 имён, 44 употреблений

historystr (14/9), historyadd (12/8), historycount (5/3), historyused (5/1), deletehistorystr (4/2), historysize (2/1), donehistory (1/1), inithistory (1/1)

## scroller.pas — 4 имён, 42 употреблений

setrange (19/9), setlimit (18/9), focusitemnum (3/1), scrolldraw (2/1)

## calendar.pas — 6 имён, 36 употреблений

curdate (11/6), dayofweek (9/4), insertcalendar (5/3), gettitle (5/1), tcalendarview (3/1), tcalendarwindow (3/1)

## version.pas — 3 имён, 36 употреблений

d2 (25/5), days (6/1), versionword (5/3)

## gauge.pas — 5 имён, 20 употреблений

clearinterior (6/4), addprogress (4/2), solveforx (4/2), solvefory (4/2), updateview (2/1)

## _gauge.pas — 5 имён, 20 употреблений

clearinterior (6/4), addprogress (4/2), solveforx (4/2), solvefory (4/2), updateview (2/1)

## gauges.pas — 7 имён, 15 употреблений

ttrashcan (4/2), tkeymacros (3/1), ptrashcan (2/1), pclockview (2/1), pkeymacros (2/1), putkey (1/1), printfiles (1/1)

## asciitab.pas — 4 имён, 15 употреблений

asciitable (6/4), ttable (3/1), treport (3/1), tasciichart (3/1)

## strview.pas — 2 имён, 8 употреблений

pdstringview (5/1), tdstringview (3/1)

## colorvga.pas — 1 имён, 7 употреблений

width (7/3)

## topview_.pas — 3 имён, 6 употреблений

tsortview (3/1), ttopview (2/2), psortview (1/1)

## helpfile.pas — 3 имён, 5 употреблений

phelpwindow (3/1), thelpwindow (1/1), gotocontext (1/1)

## usersavr.pas — 2 имён, 4 употреблений

tusersaver (3/1), insertusersaver (1/1)

## advance6.pas — 3 имён, 3 употреблений

resourceaccesserror (1/1), makecrctable (1/1), getoffsetforlinenumber (1/1)

## listmakr.pas — 2 имён, 3 употреблений

rstrlistmaker (2/1), pstrlistmaker (1/1)

(в скобках: употреблений / файлов)
