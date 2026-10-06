{/////////////////////////////////////////////////////////////////////////
//
//  Dos Navigator Open Source 1.51.08
//  Based on Dos Navigator (C) 1991-99 RIT Research Labs
//
//  This programs is free for commercial and non-commercial use as long as
//  the following conditions are aheared to.
//
//  Copyright remains RIT Research Labs, and as such any Copyright notices
//  in the code are not to be removed. If this package is used in a
//  product, RIT Research Labs should be given attribution as the RIT Research
//  Labs of the parts of the library used. This can be in the form of a textual
//  message at program startup or in documentation (online or textual)
//  provided with the package.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//  1. Redistributions of source code must retain the copyright
//     notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//  3. All advertising materials mentioning features or use of this software
//     must display the following acknowledgement:
//     "Based on Dos Navigator by RIT Research Labs."
//
//  THIS SOFTWARE IS PROVIDED BY RIT RESEARCH LABS "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
//  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The licence and distribution terms for any publically available
//  version or derivative of this code cannot be changed. i.e. this code
//  cannot simply be copied and put under another distribution licence
//  (including the GNU Public Licence).
//
//////////////////////////////////////////////////////////////////////////}
{$I STDEFINE.INC}
unit DnExec;

interface

uses
  Defines, FilesCol, Commands
  ;

procedure ExecString(const S: AnsiString; const WS: String);
  {` Execute string S^ via the command processor. WS, if not
  empty, is written to the screen before calling the cmd. processor `}
procedure ExecStringRR(S: AnsiString; const WS: String; RR: Boolean); {JO}
{JO:  differs from ExecString by the boolean RR, which}
{     indicates whether to reread the panel after execution or not           }

function SearchExt(FileRec: PFileRec; var HS: String): Boolean;
{DataCompBoy}
function ExecExtFile(const ExtFName: String; UserParams: PUserParams;
     SIdx: TStrIdx): Boolean; {DataCompBoy}
procedure ExecFile(const FileName: String); {DataCompBoy}

procedure AnsiExec(const Path: String; const ComLine: AnsiString); {JO}

const
  fExec: Boolean = False; {an external program is running}

implementation

uses DNRun,
  
  
   realmode, 
  DNUtil, basics, mainapp, strutil, Lfn,
  Dos, panelroot, CmdLine, Views, fileutil, Drivers, winsess,
  VideoMan, osdep, dnscreen, timeutil,
  
  Startup, UserMenu, Messages, Strings, filetype, TitleSet
   {AK155 for redrawing the icon}
  ;

{JO}
{ AnsiExec - analogue of DOS.Exec that uses }
{ an Ansistring as the command line }
{ and thus has no 255-character limit}
procedure AnsiExec(const Path: String; const ComLine: AnsiString);
  var
    PathBuf: array[0..255] of Char;
    Ans1: AnsiString;
    c: Longint;
    S: String;
  begin
  Ans1 := ComLine+#0;  S := ActiveDir;
  MakeNoSlash(S);
  ChDir(SysOsPath(S));
  c := IOResult;
  DosError := SysExecute(StrPCopy(PathBuf, Path), PChar(Ans1), nil,
      ExecFlags = efAsync, nil, -1, -1, -1);

//  free the directory
  if ActiveDir[2] = ':' then
    ChDir(SysOsPath(Copy(ActiveDir, 1, 2) + '\'));

  ChDir(SysOsPath(StartDir));
  end { AnsiExec };
{/JO}

{AK155 30-12-2001
This is an attempt to determine the type of the program being called, so that a GUI program
is invoked without waiting for completion, and all others with waiting.
If no extension is given, no attempt is made to recognize a GUI program.
In particular, no search of the Path environment variable is done,
because it is hard to do without being crooked. For example, if some
prog is launched, it is wrong to search the paths for prog.exe. It may happen
that we find it, while somewhere earlier, e.g. in the current directory, there is prog.com
or prog.cmd, and we would call it as if it were GUI. By the way, Far glitches exactly
like that. Put notepad.cmd in the current directory and type notepad on the command line.
Then press Enter on that very notepad.cmd.
}
{Result - subsystem code for Win32 PE, or 100 for Win16 NE,
 or 0 for others }
function Win32Program(const S: String): SmallWord;
  const
    PETag = $00004550; {'PE'#0#0}
    NETag = $454E; {'NE'}
  var
    f: file;
    PathEnv: String;
    Dir: DirStr;
    Name: NameStr;
    Ext: ExtStr;
    RealName: String;
    NewExeOffs: SmallWord;
    NewHeader: record
      signature: LongInt;
      dummy1: array[1..16] of Byte;
      SizeOfOptionalHeader: SmallWord;
      Characteristics: SmallWord;
      {OptionalHeader}
      dummy2: array[1..68] of Byte;
      Subsystem: SmallWord;
      end;
    l: LongInt;
  begin { Win32Program }
  Result := 0;
  RealName := S;
  if  (RealName[1] = '"') and ((RealName[Length(RealName)] = '"')) then
    RealName := Copy(RealName, 2, Length(RealName)-2);
  RealName := lFExpand(RealName);
  DelRight(RealName);
  FSplit(RealName, Dir, Name, Ext);
  UpStr(Ext);
  if Ext <> '.EXE' then
    Exit;
  FileMode := Open_Access_ReadOnly or open_share_DenyNone;
  ClrIO;
  Assign(f, SysOsPath(RealName));
  Reset(f, 1);
  if  (IOResult <> 0) and (Dir = '') then
    begin
    PathEnv := GetEnv('PATH');
    RealName := FSearch(S, PathEnv);
    if RealName = '' then
      Exit;
    Assign(f, SysOsPath(RealName));
    Reset(f, 1);
    if IOResult <> 0 then
      Exit; {in general this should not happen, since we found it}
    end;
  Seek(f, $3C);
  BlockRead(f, NewExeOffs, 2, l);
  if  (NewExeOffs = 0) or (l <> 2) then
    begin
    Close(f); {Cat}
    Exit;
    end;
  Seek(f, NewExeOffs);
  BlockRead(f, NewHeader, SizeOf(NewHeader), l);
  Close(f);
  with NewHeader do
    begin
    if SmallWord(signature) = NETag then
      Result := 100
    else if (l >= 70) and (signature = PETag)
         and (SizeOfOptionalHeader >= 70)
    then
      Result := Subsystem;
    end;
  end { Win32Program };





{-DataCompBoy-}
procedure ExecStringRR(S: AnsiString; const WS: String; RR: Boolean); {JO}
  var
    I: Integer;
    EV: TEvent;
    X, Y: SmallWord; {Cat}
    ScreenSize: TSysPoint; {Cat}
    
    DosRunString: String;
    
    ActDir1: String;

  begin
  
  if TimerMark then
    DDTimer := GetCurMSec
  else
    DDTimer := 0;
  if WS <> '' then
    Writeln(WS);
  SetTitle(S);
  fExec := True;
  
  
  SaveDsk;
  DNRun.QuietRun := not RR;
  DNRun.RunExternal(S);
  DNRun.QuietRun := False;
  
  fExec := False;
  {AK155, Cat: so the command line and menu do not overlap the output}
  GetCursorXY(X, Y);
  if InterfaceData.Options and ouiHideStatus = 0 then
    Inc(Y);
  if X <> 0 then
    Writeln;
  GetScreenMode(@ScreenSize, True);
  if Y >= ScreenSize.Y then
    Writeln;
  {/AK155, Cat}
  if TimerMark then
    begin
    DDTimer := GetCurMSec - DDTimer;
    EV.What := evCommand;
    EV.Command := cmShowTimeInfo;
    EV.InfoPtr := nil;
    Application.PutEvent(EV);
    end;
  I := DosError;
  ClrIO;
  SwapVectors;
  EraseFile(SwpDir+'$DN'+ItoS(DNNumber)+'$.LST'); {DataCompBoy}
  { the screen of TV, the events and the memory are not stopped for the program: nothing to start again }
  
  Application.Redraw;
  {JO}
  if RR then
    begin
    ActDir1 := '>' + ActiveDir; //flag to reread subdirectories in the branch
    GlobalMessage(evCommand, cmPanelReread, @ActDir1);
    GlobalMessage(evCommand, cmRereadInfo, nil);
    end;
  {/JO}

  {AK155 without this the command-line cursor does not go back into place}
  
  {/AK155}
  end { ExecStringRR };
{-DataCompBoy-}

{JO}
procedure ExecString(const S: AnsiString; const WS: String);
  begin
  ExecStringRR(S, WS, True);
  end;
{/JO}
{-DataCompBoy-}
function SearchExt(FileRec: PFileRec; var HS: String): Boolean;
  var
    AllRight: Boolean;
    f: TTextReader;
    F1: lText;
    s, s1: String;
    BgCh, EnCh: Char;
    EF, First: Boolean;
    I: Integer;
    Local: Boolean;
    FName: String;
    UserParam: tUserParams;
    
  label RL;

  begin
  First := True;
  Message(Desktop, evBroadcast, cmGetUserParams, @UserParam);
  UserParam.Active := FileRec;
  FName := FileRec^.FlName[True];
  {lGetDir(0, ActiveDir);}
  {Cat:warn commented this out while hunting bugs, but need to check whether new ones were introduced}
  SearchExt := False;
  Local := True;
  f := TTextReader.Create('dn.ext');
  if f = nil then
    begin
RL:
    Local := False;
    f := TTextReader.Create(SourceDir+'dn.ext');
    end;
  if f = nil then
    Exit;
  AllRight := False;
  BgCh := '{';
  EnCh := '}';
  Abort := False;
  EF := False;
  if PShootState and 8 > 0 then
    begin
    BgCh := '[';
    EnCh := ']';
    end
  else if PShootState and 3 > 0 then
    begin
    BgCh := '(';
    EnCh := ')';
    end;
  while (not f.Eof) and (not AllRight) do
    begin
    s := f.GetStr;
    if s[1] <> ' ' then
      begin
      I := PosChar(BgCh, s);
      if  (I = 0) or (s[I+1] = BgCh) then
        Continue;
      s1 := Copy(s, 1, I-1);
      DelLeft(s1);
      DelRight(s1);
      if s1[1] <> ';' then
        begin
        if InExtFilter(FName, s1) then
          begin
          lAssignText(F1, SwpDir+'$DN'+ItoS(DNNumber)+'$'+CmdExt);
          ClrIO;
          lRewriteText(F1);
          if IOResult <> 0 then
            begin
            f.Free;
            Exit;
            end;
          
          Writeln(F1.T, '@echo off');
          
          System.Delete(s, 1, PosChar(BgCh, s));
          repeat
            Replace(']]', #0, s);
            Replace('))', #1, s);
            Replace('}}', #2, s);
            DelLeft(s);
            DelRight(s);
            if s[Length(s)] = EnCh then
              begin
              SetLength(s, Length(s)-1);
              EF := True;
              if s <> '' then
                begin
                Replace(#0, ']', s);
                Replace(#1, ')', s);
                Replace(#2, '}', s);
                s := MakeString(s, @UserParam, False, nil);
                HS := s;
                
                Writeln(F1.T, s);
                Break
                end;
              end;
            if s <> '' then
              begin
              Replace(#0, ']', s);
              Replace(#1, ')', s);
              Replace(#2, '}', s);
              if  (BgCh <> '[') then
                s := MakeString(s, @UserParam, False, nil);
              if First and (BgCh <> '[') then
                HS := s;
              
              Writeln(F1.T, s);
              First := False;
              end;
            if  (f.Eof) then
              Break;
            if not EF then
              s := f.GetStr;
          until (IOResult <> 0) or Abort or EF;
          Close(F1.T);
          AllRight := True;
          end;
        end;
      end;
    end;
  f.Free;
  {D.Filter:=''; MakeTMaskData(D);}
  if not EF and not Abort and Local then
    goto RL;
  if EF and (BgCh = '[') then
    begin
    EraseFile(SwpDir+'$DN'+ItoS(DNNumber)+'$.MNU');
    lRenameText(F1, SwpDir+'$DN'+ItoS(DNNumber)+'$.MNU');
    EF := ExecUserMenu(False);
    if not EF then
      lEraseText(F1);
    end;
  SearchExt := not Abort and EF;
  end { SearchExt };
{-DataCompBoy-}

{-DataCompBoy-}
function ExecExtFile(const ExtFName: String; UserParams: PUserParams;
     SIdx: TStrIdx): Boolean;
  var
    F: TTextReader;
    S, S1: String;
    FName: String;
    Event: TEvent;
    I, J: Integer;
    Success, CD: Boolean;
    Local: Boolean;
  label 1, 1111, RepeatLocal;

  begin
  ExecExtFile := False;
  FileMode := $40;
  Local := True;
  FName := UserParams^.Active.FlName[True];

  F := TTextReader.Create(ExtFName);

  if F = nil then
    begin
RepeatLocal:
    Local := False;
    F := TTextReader.Create(SourceDir+ExtFName);
    end;
  if F = nil then
    Exit;
  while not F.Eof do
    begin
    S := F.GetStr;
    DelLeft(S);
    S1 := fDelLeft(Copy(S, 1, pred(PosChar(':', S))));
    if  (S1 = '') or (S1[1] = ';') then
      Continue;
    if InExtFilter(FName, S1) then
      goto 1111;
    end;
  ExecExtFile := False;
  F.Free;
  {D.Filter := ''; MakeTMaskData(D);}
  if Local then
    goto RepeatLocal;
  Exit;
1111:
  Delete(S, 1, Succ(Length(S1)));
  F.Free;

  // AK155 27/08/05 Since DN/2 does not terminate when executing
  // an external command, there is no need to check Valid(cmQuit)
  if not Application.Valid(cmQuit) then
    begin
    Exit;
    end;

  ClrIO;
  S1 := '';
  S := MakeString(S, UserParams, False, @S1);
  if S1 <> ''
  then
    TempFile := '!'+S1+'|'+MakeNormName(UserParams^.Active.Owner^, FName)
  else if TempFile <> ''
  then
    TempFile := MakeNormName(UserParams^.Active.Owner^, FName);
  {if TempFile <> '' then SaveDsk;}
 
  if Abort then
    begin
    Exit;
    end;
  if S[1] = '*' then
    Delete(S, 1, 1); {DelFC(S);}
  lGetDir(0, S1);
  
  if UpStrg(MakeNormName(lfGetLongFileName(UserParams^.Active.Owner^),
         '.')) <>
    UpStrg(MakeNormName(S1, '.'))
  then
    begin
    DirToChange := S1;
    lChDir(lfGetLongFileName(UserParams^.Active.Owner^));
    end;
  
  ExecExtFile := True;
  
  ExecStringRR(S, '', False);
 
  end { ExecExtFile };
{-DataCompBoy-}

{-DataCompBoy-}
procedure ExecFile(const FileName: String);
  var
    S, M: String;
    fr: PFileRec;

  procedure PutHistory(B: Boolean);
    begin
    if M = '' then
      Exit;
    CmdLine.Str := M;
    CmdLine.StrModified := True;
    CmdDisabled := B;
    MessageKey(CommandLine, kbDown);
    MessageKey(CommandLine, kbUp);
    end;

  procedure RunCommand(B: Boolean);
    var
      ST: SessionType;
      S: String; {//AK155}
    begin
    if  (TCommandLine(CommandLine).LineType in [ltWindow,
         ltFullScreen])
    then
      begin
      if TCommandLine(CommandLine).LineType = ltFullScreen then
        ST := stFullScreen
      else
        ST := stWindowed;
      RunSession(M, False, ST);
      CmdLine.StrModified := True;
      MessageKey(CommandLine, kbDown);
      Exit;
      end;
    {AK155, see dnutil.ExecCommandLine}
    S := '';
    CommandLine.SetData(S);
    {/AK155}
    if B then
      ExecString(M, #13#10+ (ActiveDir)+'>'+ (M))
    else
      ExecString(M, '');
    end { RunCommand };

  label ex;
  begin { ExecFile }
  fr := CreateFileRec(FileName);
  S := fr^.FlName[True];
  FreeStr := '';
  M := '';
  if  (ShiftState and (3 or kbAltShift) <> 0) or
      not InExtFilter(S, Executables)
  then
    begin
    if SearchExt(fr, M) then
      begin
      {PutHistory(true);}
      M := SwpDir+'$DN'+ItoS(DNNumber)+'$'+CmdExt+' '+FreeStr;
      RunCommand(False);
      {M := S; PutHistory(false);}
      {CmdDisabled := false;}
      GlobalMessage(evCommand, cmClearCommandLine, nil);
      end;
    goto ex;
    end;
  
  M := S;
  
  PutHistory(False);
  M := S;

  if Pos(' ', M) <> 0 then
    {AK155}
    M := '"'+M+'"';

  RunCommand(True);
ex:
  DelFileRec(fr);
  end { ExecFile };

end.
