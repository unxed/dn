{ The sharing bits and the like of the unit Streams of DN. The resources are RStrings and DNStrL (carved from COLLECT.PAS). }
const
  { the sharing bits of the open mode of a file (DOS: the bits 4..7 of the mode; VP has the same names); TDosStream of
    tv/ ignores them (DN: Init(Name, (stOpenRead and fmDeny) or fmDenyWrite) asks for "deny write") }
  fmDenyAll = $10;
  fmDenyWrite = $20;
  fmDenyRead = $30;
  fmDenyNone = $40;
  fmDeny = $70;
  fmDenyChild = $80;
