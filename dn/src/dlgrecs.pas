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
{AK155  3.06.2007 To reduce circular unit references,
 former dlgrecs.pas was split into two modules: dlgrecs.pas and dlgrecs.pas,
 the first holding most of what other units reference
 but with an almost empty uses list }

unit dlgrecs;

interface

uses
  Defines, Startup, Collect, calcline
  ;

type

  {Cat: removed, because TTextCollection = TLineCollection}
  (*
  PTextCollection =^TTextCollection;
  TTextCollection = class( TCollection )
    procedure FreeItem( Item: Pointer ); virtual;
    procedure PutItem(var S: TStream; Item: Pointer); virtual;
    function GetItem(var S: TStream): Pointer; virtual;
  end;
*)
  PTextCollection = TLineCollection;
  TTextCollection = TLineCollection;
  {/Cat}

  TListBoxRec = record
    List: TCollection;
    Focus: Word
    end;
  TTextListboxRec = record
    List: PTextCollection;
    Focus: Word
    end;

  
  TSaversData = record
    Selected: TTextListboxRec;
    Available: TTextListboxRec;
    Time: String[3]; {DataCompBoy}
    Mouse: Boolean;
    _: Byte;
    end;

  TOldSaversData = record
    Selected: TTextListboxRec;
    Available: TTextListboxRec;
    Time: AWord;
    Mouse: Boolean;
    _: Byte;
    end;
  
const
  
  SaversData: TSaversData = (
    Selected: (List: nil; Focus: 0);
    Available: (List: nil; Focus: 0);
    Time: '5';
    Mouse: True
    );
  

  MaxCalcFormat: TCalcFormat =
    (18, 8, 32, 11, 18, 9);
  CalcFormat: TCalcFormat =
    (18, 8, 32, 11, 18, 1);

implementation
uses
  osdep, basics, strutil, fileutil,
  Lfn, CfgDir, DnPath
  , Dos, SysUtils;

begin
TempDir := '';
TempFile := '';

SourceDir := lFExpand(ParamStr(0));
while (SourceDir <> '') and not IsPathSep(SourceDir[Length(SourceDir)]) do
  SetLength(SourceDir, Length(SourceDir)-1);
StartupDir := SourceDir;
{SourceDir := Dos.GetEnv('DN')}
{Cat: replaced DNVP with DN2 — much more logical}
(*
  if ExistDir(Dos.GetEnv('DNVP')) or (Dos.GetEnv('DNVP')='') then
      SourceDir := Dos.GetEnv('DNVP')
     else
      Writeln('Warning! Path specified in DNVP environment variable does not exist!');
*)
SourceDir := Dos.GetEnv('DN2');
DelLeft(SourceDir);
if SourceDir <> '' then
  SourceDir := lFExpand(SourceDir);        { a path of the system (/home/x) is a path of DN (\home\x) }
{ the file system is asked directly: the current directories of Lfn are not known yet }
if (SourceDir <> '') and not DirectoryExists(SysOsPath(SourceDir)) then
  begin
  Writeln(
    'Warning! Path specified in DN2 environment variable does not exist!');
  SourceDir := '';
  end;

if SourceDir = '' then
  SourceDir := StartupDir;
MakeSlash(SourceDir);
{ the files that the user changes: his configuration directory, but DN2 (an explicit directory) keeps everything together as before }
if Dos.GetEnv('DN2') = '' then
  begin
  ConfigDir := UserConfigDir(SourceDir);
  StateDir := UserStateDir(ConfigDir);
  CacheDir := UserCacheDir(ConfigDir);
  end
else
  begin
  ConfigDir := SourceDir;
  StateDir := SourceDir;
  CacheDir := SourceDir;
  end;

StartupDir := lfGetLongFileName(StartupDir);
SourceDir := lfGetLongFileName(SourceDir);
ConfigDir := lfGetLongFileName(ConfigDir);
StateDir := lfGetLongFileName(StateDir);
CacheDir := lfGetLongFileName(CacheDir);
TempDir := lfGetLongFileName(TempDir);
TempFile := lfGetLongFileName(TempFile);

end.

