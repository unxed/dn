{osdep extension unit by Jaroslaw Osadtchiy (JO) <2:5030/1082.53>}
{Modified for compatibility with DPMI32 by Aleksej Kozlov (Cat) <2:5030/1326.13>}
{Contribution to Dos Navigator /2 OSP project}
{&OrgName+,Speed+,AlignCode+,AlignRec-,CDecl-,Far16-,Frame+,Delphi+}
{$X+,W-,I-,J+,H-,Delphi+,R-,S-,Q-,B-,T-,Use32+}

unit osfind;

interface

uses
  osdep
  
  
  ;



type
  POSSearchRec = ^TOSSearchRec;

  TOSSearchRecNew = packed record
    Handle: LongInt;
    NameLStr: Pointer;
    Attr: Byte;
    Time: LongInt;
(*
{$IFNDEF DPMI32}
    Size: Int64; {AK155 то есть TSize}
{$ELSE}
    Size: Longint;
{$ENDIF}
*)
    Size: TFileSize;
    Name: ShortString;
    Filler: array[0..3] of Char;
    
    
    
    attr_must: Byte;
    dos_dta:
    record
      fill: array[1..21] of Byte;
      Attr: Byte;
      Time: LongInt;
      Size: LongInt;
      Name: array[0..12] of Char;
      end;
    
    {$IFDEF LINUX}
    FindDir: array[0..255] of Char;
    FindName: ShortString;
    FindAttr: LongInt;
    {$ENDIF}
    CreationTime: LongInt;
    LastAccessTime: LongInt;
    end;

function SysFindFirstNew(Path: PChar; Attr: LongInt;
     var F: TOSSearchRecNew; IsPChar: Boolean): LongInt;
function SysFindNextNew(var F: TOSSearchRecNew; IsPChar: Boolean): LongInt;
function SysFindCloseNew(var F: TOSSearchRecNew): LongInt;

procedure SysTVKbdDone;

implementation

{&OrgName-}

uses
  Strings
  ;

function SysFindFirstNew(Path: PChar; Attr: LongInt;
     var F: TOSSearchRecNew; IsPChar: Boolean): LongInt;
 
  begin
  SysFindFirstNew := SysFindFirst(Path, Attr, POSSearchRec(@F)^, IsPChar)
    ;
  end; 

function SysFindNextNew(var F: TOSSearchRecNew; IsPChar: Boolean): LongInt;
 
  begin
  SysFindNextNew := SysFindNext(POSSearchRec(@F)^, IsPChar);
  end; 

function SysFindCloseNew(var F: TOSSearchRecNew): LongInt;
 
  begin
  SysFindCloseNew := SysFindClose(POSSearchRec(@F)^);
  end; 

procedure SysTVKbdDone;
 
  begin
  end; 




type
  TDateTimeRec = record
    FTime, FDate: SmallWord;
    end;

  





end.
