{ DPMI-specific time and events tools by A.Korop (AK155)}


unit Events;

interface
{$I Events.inc}

implementation

uses
  VPUtils
  ;

function GetCurMSec: Longint;
  begin
  Result := GetTimeMSec;
  end;

procedure LongWorkBegin;
  begin
  end;

procedure LongWorkEnd;
  begin
  end;

end.

