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
{Writted by DataCompBoy at 29.07.2000 21:04:26}
{AK155 = Alexey Korop, 2:461/155@fidonet}
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}

{Cat
   28/08/2001 - переделал функции для совместимости с типами AnsiString и
   LongString, а также для поддержки коллекций с длинными строками

   05/09/2001 - выкинул NeedStream из GetWinClip и SyncClipOut
}

unit WINCLP;

interface

uses
  Defines, Streams, Collect
  ;

function SetWinClip(PC: PLineCollection): Boolean; 
function GetWinClip(var PCL: PLineCollection {; NeedStream: boolean})
  : Boolean; 
function GetWinClipSize: Boolean; 
procedure SyncClipIn; 
procedure SyncClipOut {(NeedStream: boolean)}; 

procedure CopyLines2Stream(PC: PCollection; var PCS: PStream);
procedure CopyStream2Lines(PCS: PStream; var PC: PCollection);

implementation



function SetWinClip(PC: PLineCollection): Boolean; 
  
  begin {Cat:todo DPMI32}
  end; 

function GetWinClip(var PCL: PLineCollection {; NeedStream: boolean})
  : Boolean; 
  
  begin {Cat:todo DPMI32}
  end; 

function GetWinClipSize: Boolean; 
  
  begin {Cat:todo DPMI32}
  end; 

procedure SyncClipIn; 
  
  begin {Cat:todo DPMI32}
  end; 

procedure SyncClipOut {(NeedStream: boolean)}; 
  
  begin {Cat:todo DPMI32}
  end; 

procedure CopyLines2Stream(PC: PCollection; var PCS: PStream);
 
  begin {Cat:todo DPMI32}
  end; 

procedure CopyStream2Lines(PCS: PStream; var PC: PCollection);
 
  begin {Cat:todo DPMI32}
  end; 

end.
