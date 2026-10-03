unit dirwatch;
(******

{Заглушка для D32}
Directory Change Notifier - Win32 version
Written by Cat 2:5030/1326.13
(for use in DN/2)

******)

interface

 uses timeutil;

Var
 NotifyTmr: TEventTimer;       {JO}

procedure NotifyInit;
procedure NotifyAddWatcher(const Path: String);
procedure NotifyDeleteWatcher(const Path: String);
function NotifyAsk(var S: String): Boolean;
procedure NotifySuspend;
procedure NotifyResume;
procedure NotifyDone;

implementation

procedure NotifyInit;
begin end;

procedure NotifyAddWatcher(const Path: String);
begin end;

procedure NotifyDeleteWatcher(const Path: String);
begin end;

function NotifyAsk(var S: String): Boolean;
begin Result := False end;

procedure NotifySuspend;
begin end;

procedure NotifyResume;
begin end;

procedure NotifyDone;
begin end;

end.
