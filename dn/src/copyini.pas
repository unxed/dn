unit CopyIni;
{AK155}

interface

procedure CopyIniVarsToCfgVars;

implementation
uses
  DnIni, Startup, strutil, panelroot
  , dirwatch
  
  , Commands
  ;

procedure CopyIniVarsToCfgVars;
  var
    i: Integer;
  begin
  if SystemDataOpt <> 65535 then
    SystemData.Options := SystemDataOpt;
  if InterfaceDataOpt <> 65535 then
    InterfaceData.Options := InterfaceDataOpt;
  if FMSetupOpt <> 65535 then
    Startup.FMSetup.Options := FMSetupOpt;
  if EditorDefaultsOpt <> 65535 then
    EditorDefaults.EdOpt := EditorDefaultsOpt;
  if EditorDefaultsOpt2 <> 65535 then
    EditorDefaults.EdOpt2 := EditorDefaultsOpt2;
  if ViewerOpt <> 65535 then
    EditorDefaults.ViOpt := ViewerOpt;
  if StartupDataLoad <> 65535 then
    StartupData.Load := StartupDataLoad;
  if StartupDataUnload <> 65535 then
    StartupData.Unload := StartupDataUnload;
  if ConfirmsOpt <> 65535 then
    Confirms := ConfirmsOpt;
  SystemData.CopyLimitBuf := CopyLimit;
  SystemData.ForceDefArch := ForceDefaultArchiver;
  for i := 0 to 8 do
    DisposeStr(DirsToChange[i]);
  DirsToChange[0] := NewStr(QDirs1);
  DirsToChange[1] := NewStr(QDirs2);
  DirsToChange[2] := NewStr(QDirs3);
  DirsToChange[3] := NewStr(QDirs4);
  DirsToChange[4] := NewStr(QDirs5);
  DirsToChange[5] := NewStr(QDirs6);
  DirsToChange[6] := NewStr(QDirs7);
  DirsToChange[7] := NewStr(QDirs8);
  DirsToChange[8] := NewStr(QDirs9);
    
  end { CopyIniVarsToCfgVars };

end.
