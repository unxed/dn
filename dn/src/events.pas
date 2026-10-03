{ DPMI-specific time and events tools by A.Korop (AK155)}


unit Events;

interface
{$I Events.inc}

implementation

uses SysUtils
  ;

function GetCurMSec: Longint;
  begin
  Result := LongInt(Cardinal(GetTickCount64 and $FFFFFFFF));
  end;

procedure LongWorkBegin;
  begin
  end;

procedure LongWorkEnd;
  begin
  end;

end.

