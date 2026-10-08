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

unit envutil; {Misc stuff}

interface

function GetSTime: LongInt;

function FindParam(const S: String): Integer;
  {` Finds among ParamStr the parameter that starts
    with '/' or '-' and then S. Result is that parameter's index. `}

function Chk4Dos: Boolean;

function GetEnv(S: String): String;

implementation

uses
  basics, Dos,
  strutil, linepos, Commands {Cat}
  ;

function GetSTime: LongInt;
  var
    H, M, S, SS: Word;
  begin
  GetTime(H, M, S, SS);
  GetSTime := SS+LongInt(S)*100+LongInt(M)*6000+LongInt(H)*360000;
  end;

function FindParam(const S: String): Integer;
  var
    I: Integer;
  begin
  FindParam := 0;
  {$IFDEF UNIX}
  { on Unix a word that starts with "/" is a path, the switches start with "-" }
  if S[1] = '/' then
    begin
    FindParam := FindParam('-'+Copy(S, 2, MaxStringLength));
    Exit;
    end;
  {$ENDIF}
  for I := 1 to ParamCount do
    if S = Copy(UpStrg(ParamStr(I)), 1, Length(S)) then
      begin
      FindParam := I;
      Exit
      end;
  if S[1] = '/' then
    FindParam := FindParam('-'+Copy(S, 2, MaxStringLength));
  end;


function Chk4Dos: Boolean;
  begin
  Result := False;   { INT 2Fh AX=D44Dh: the loader of DN (DN.COM) is not there }
  end;


function GetEnv(S: String): String;
  begin
  S := Dos.GetEnv(S);
  DelSpace(S);
  GetEnv := S;
  end;

end.
