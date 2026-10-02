{ Files: names of the file layer of DN that the archive does not have (our unit, written from the use of the
  names; see research/dn-port-lessons.md). TODO: more names as the units of DN that use it compile. }
{$mode objfpc}{$H-}
unit Files;

interface

type
  { the index of the names of a file: a short one (8.3) or a long one }
  TUseLFN = Boolean;

const
  uLfn = True;
  uNLfn = False;

implementation

end.
