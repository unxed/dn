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

unit palettes;

{ Carved by tools/dn-carve.py from mainapp.PAS: the constants CColor, CBlackWhite, CMonochrome of Dos Navigator. }

interface

uses
  Defines;

const
  CColor =
  #$0A#$70#$79#$75#$30#$39#$35#$8C#$8B#$8A#$31#$31#$78#$7F#$1F+
  #$31#$3F#$3A#$13#$13#$3E#$21#$3F#$70#$7F#$7A#$13#$13#$70#$7F#$7E+
  #$70#$70#$73#$13#$13#$70#$70#$7F#$75#$5B#$6F#$CF#$78#$5D#$78#$70+
  #$7F#$76#$0F#$9F#$0B#$9F#$79#$87#$78#$30#$0F#$3F#$31#$70#$79#$3E+
  #$30#$38#$3F#$0F#$07#$0B#$87#$8F#$87#$87#$8B#$B0#$87#$7F#$1C#$00+
  #$87#$8B#$87#$8B#$B0#$8B#$8B#$0F#$30#$7F#$30#$8B#$87#$70#$87#$8F+
  #$3F#$8F#$3F#$8E#$8E#$70#$8B#$87#$30#$3F#$0F#$3E#$0E#$31#$31#$00+
  #$87#$8F#$87#$8B#$B0#$87#$70#$8B#$30#$3F#$87#$8F#$87#$8F#$70#$7F+
  #$8F#$30#$8B#$83#$7F#$79#$39#$7E#$7E#$7F#$70#$37#$3F#$3F#$13#$13+
  #$30#$3F#$8F#$30#$38#$3E#$0F#$07#$0E#$87#$8B#$87#$87#$8B#$B0#$87+
  #$70#$8E#$30#$3B#$83#$8E#$38#$3F#$3A#$31#$3F#$70#$87#$8F#$8D#$89+
  #$84#$82#$C8#$6D#$80#$8C#$0C#$7C#$0B#$0F#$8B#$8B#$8E#$8F#$8D#$8B+
  #$83#$86#$81#$8E#$8A#$8F#$8E#$83#$8F#$8D#$8B#$8F#$8E#$70#$3F#$30+
  #$73#$3B#$70#$73#$3F#$3F#$4F#$4F#$70#$0F#$78#$7E#$48#$0E#$3F#$3F+
  #$08#$CF#$CE#$0F#$0E;
  CBlackWhite =
  #$0F#$70#$78#$7F#$07#$07#$0F#$07#$0F#$07#$70#$70#$07#$70#$0F+
  #$07#$0F#$07#$70#$70#$07#$70#$0F#$70#$7F#$7F#$70#$07#$70#$07#$0F+
  #$70#$7F#$7F#$70#$07#$70#$70#$7F#$7F#$07#$0F#$0F#$78#$0F#$78#$70+
  #$7F#$7F#$0F#$70#$0F#$07#$70#$70#$70#$07#$70#$0F#$07#$07#$78#$00+
  #$70#$78#$7F#$07#$07#$0F#$07#$0F#$0F#$0F#$70#$70#$07#$70#$07#$00+
  { 64 - 79 Editor}
  #$07#$0F#$0F#$70#$70#$07#$07#$F0#$70#$7F#$7F#$0F#$70#$70#$07#$07+
  #$70#$0F#$7F#$0F#$0F#$07#$70#$7F#$0F#$0F#$0F#$70#$7F#$0F#$0F#$00+
  #$07#$0F#$0F#$78#$78#$07#$78+
  #$07#$70#$7F#$07#$0F#$07#$0F+ {119 - 125 - File Info}
  #$70#$7F#$07#$0F#$07#$08#$7F#$79#$39#$7E#$7E#$7F#$70+
  {126 - 138 - File Find}
  #$07#$0F#$07#$70#$70#$07#$0F#$70+
  #$70#$78#$7F#$07#$07#$0F#$07#$0F#$0F#$0F#$70#$70#$07#$70#$0F#$70+
  #$0F#$08#$0F#$07#$0F#$0F#$0F#$07#$70#$07#$0F#$08#$07#$07#$07#$7F+
  #$7F#$07#$07#$0F#$78#$08#$0F#$0F#$0F#$78#$0F#$0F#$0F#$07#$07#$07+
  #$07#$07#$0F#$0F#$08#$0F#$0F#$0F#$0F#$0F#$70#$1F#$80#$7F#$8F#$78+
  #$7F#$0F#$0F#$70#$70#$07#$07#$08#$0F#$78#$7F#$1F#$17#$71#$30#$3F#$3F#$3F;
  CMonochrome =
  #$70#$07#$07#$01#$70#$70#$0F#$07#$0F#$0F#$0F#$0F#$70#$0F#$1F+
  #$31#$3F#$3A#$13#$13#$3E#$21#$3F#$70#$70#$0F#$13#$13#$70#$7F#$7E+
  #$70#$70#$70#$0F#$0F#$70#$70#$70#$0F#$07#$07#$07#$07#$01#$70#$70+
  #$07#$0F#$07#$70#$0F#$0F#$70#$0F#$0F#$07#$70#$01#$07#$70#$70#$0F+
  #$70#$70#$01#$0F#$07#$01#$07#$0F#$0F#$0F#$0F#$0F#$07#$70#$1C#$00+
  { 64 - 79 Editor}
  #$07#$0F#$0F#$0F#$0F#$07#$0F#$01#$70#$70#$70#$0F#$07#$0F#$07#$07+
  #$70#$0F#$70#$01#$01#$70#$0F#$07#$07#$07#$70#$0F#$70#$01#$01#$00+
  #$07#$0F#$0F#$0F#$0F#$07#$70+
  #$0F#$07#$0F#$07#$0F#$07#$0F+ {119 - 125 - File Info}
  #$70#$7F#$70#$0F#$0F#$07#$01#$79#$39#$7E#$7E#$7F#$70+
  {126 - 138 - File Find}
  #$07#$07#$0F#$0F#$0F#$07#$0F#$70+
  #$70#$70#$01#$0F#$07#$01#$07#$0F#$0F#$0F#$0F#$0F#$07#$70#$70#$70+
  #$01#$01#$0F#$07#$0F#$0F#$0F#$07#$0F#$07#$07#$07#$07#$07#$07#$0F+
  #$01#$07#$07#$01#$70#$0F#$01#$07#$0F#$70#$0F#$01#$0F#$07#$07#$07+
  #$07#$07#$0F#$0F#$01#$0F#$0F#$0F#$0F#$0F#$07#$3F#$70#$0F#$70#$01+
  #$0F#$0F#$0F#$70#$70#$07#$07#$07#$01#$70#$0F#$3F#$3F#$01#$70#$70#$07#$0F;

implementation


end.
