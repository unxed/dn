{ The names DN takes from its own unit Defines (the interface part of the shim Defines; the types of the
  geometry come from tvgeom). Written from the use of the names in the DN sources. }
const
  MaxLongStringLength = 1048575;
  MaxBytes = 128 * 1024 * 1024;
  MaxWords = MaxBytes div SizeOf(Word);
  MaxPtrs = MaxBytes div SizeOf(Pointer);

type
  Str2 = String[2];   PStr2 = ^Str2;
  Str3 = String[3];   PStr3 = ^Str3;
  Str4 = String[4];   PStr4 = ^Str4;
  Str5 = String[5];   PStr5 = ^Str5;
  Str6 = String[6];   PStr6 = ^Str6;
  Str8 = String[8];   PStr8 = ^Str8;
  Str12 = String[12]; PStr12 = ^Str12;
  Str40 = String[40]; PStr40 = ^Str40;
  Str50 = String[50]; PStr50 = ^Str50;

  PString = ^String;
  LongString = AnsiString;
  PLongString = ^LongString;

  TCharSet = set of Char;
  PCharSet = ^TCharSet;

  WordRec = record
    Lo, Hi: Byte;
  end;
  LongRec = record
    Lo, Hi: SmallWord;
  end;

  SW_Word = LongInt;
  Sw_Integer = LongInt;

  { 16-bit integers of the records that are read from files }
  AInt = SmallInt;
  AWord = Word;

  PByteArray = ^TByteArray;
  TByteArray = array[0..MaxBytes - 1] of Byte;
  PWordArray = ^TWordArray;
  TWordArray = array[0..MaxWords - 1] of Word;
  PAWordArray = ^TAWordArray;
  TAWordArray = array[0..MaxWords - 1] of AWord;
  PPointerArray = ^TPointerArray;
  TPointerArray = array[0..MaxPtrs - 1] of Pointer;

  FNameStr = String;
  AsciiZ = array[0..255] of Char;

  { VP gives these names to every unit; here they come with Defines, which all the DN units use }
  TFileSize = osdep.TFileSize;
  SmallWord = osdep.SmallWord;
  TQuad = osdep.TQuad;
  TSize = TFileSize;               { the size of a file }

  { A table of a conversion of characters: the index is a character of the source encoding, the element is
    the character of the target one. }
  PXLat = ^TXlat;
  TXlat = array[Char] of Char;

procedure Beep(Freq, Dur: LongInt);
{ The free memory of the heap and its largest free block (bytes; VP and BP have them built in). }
function MemAvail: LongInt;
function MaxAvail: LongInt;

var
  { VP: the environment block of the program (the strings one after another, a double NUL at the end). TODO: not filled }
  Environment: PByteArray = nil;
