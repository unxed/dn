{ Use16: 16-bit Integer and Word, as in Turbo Pascal (our unit; a unit that uses it gets the types of a
  16-bit program, for the files and the structures of the old formats). In Virtual Pascal Integer and Word are
  32-bit and DN is written for that; in FPC (mode objfpc) Integer is 32-bit and Word is 16-bit. }
{$mode objfpc}{$H-}
unit Use16;

interface

type
  Integer = SmallInt;
  Word = System.Word;

implementation

end.
