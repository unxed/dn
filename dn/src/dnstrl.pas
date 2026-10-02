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

unit DNStrL;

{ Carved by tools/dn-carve.py from COLLECT.PAS: the classes TStringList of Dos Navigator. }

interface

uses
  Defines, Objects2, Streams, Advance1;

type
  TStrIndexRec = record
    Key, Count, Offset: AWord;
    end;

  PStrIndex = ^TStrIndex;

  TStrIndex = array[0..9999] of TStrIndexRec;

  PStringList = ^TStringList;
  TStringList = object(TObject)
    constructor Load(var S: TStream);
    destructor Done; virtual;
    function Get(Key: AWord): String;
  private
    Stream: PStream;
    BasePos: LongInt;
    IndexSize: AWord;
    Index: PStrIndex;
    procedure ReadStr(var S: String; Offset, Skip: AWord);
    end;

implementation

constructor TStringList.Load(var S: TStream);
  var
    Size: AWord;
  begin
  TObject.Init;
  Stream := @S;
  S.Read(Size, SizeOf(Size));
  BasePos := i32(S.GetPos);
  S.Seek(BasePos+Size);
  S.Read(IndexSize, SizeOf(IndexSize));
  GetMem(Index, IndexSize*SizeOf(TStrIndexRec));
  S.Read(Index^, IndexSize*SizeOf(TStrIndexRec));
  end;

destructor TStringList.Done;
  begin
  FreeMem(Index, IndexSize*SizeOf(TStrIndexRec));
  end;

function TStringList.Get(Key: AWord): String;
  var
    I: AWord;
    S: String;
  begin
  S := '';
  if  (IndexSize > 0) then
    begin
    I := 0;
    while (I < IndexSize) and (S = '') do
      begin
      if  (Word(Key-Index^[I].Key) < Index^[I].Count) then
        ReadStr(S, Index^[I].Offset, Key-Index^[I].Key);
      Inc(I);
      end;
    end;
  Get := S;
  end;

procedure TStringList.ReadStr(var S: String; Offset, Skip: AWord);
  {
var
  B: Byte; }
  begin
  Stream^.Seek(BasePos+Offset);
  Stream^.Status := 0;
  Inc(Skip);
  repeat
    {Cat}
    (*
    Stream^.Read(B, 1);
    SetLength(S, B);
    Stream^.Read(S[1],B);
*)
    Stream^.ReadStrV(S);
    {/Cat}
    Dec(Skip);
  until Skip = 0;
  end;


end.
