{ What DN calls from its unit Events besides the names of TV (the interface part of the shim Events;
  the list of the routines is the file Events.inc of the archive). }
{ The time since the start of the system in milliseconds (wraps round like a LongInt). }
function GetCurMSec: LongInt;
{ A long work begins/ends: a hint to lower/restore the priority of the process (a no-op where the system
  has no such thing). }
procedure LongWorkBegin;
procedure LongWorkEnd;
