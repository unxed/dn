{ HelpKern: the help kernel of DN is the help of our TV (tv/src/tvhelp.pas); this unit only gives the names that the
  code of DN uses (the types are the same types: regall registers them for the streams). }
{$mode objfpc}{$H-}
unit HelpKern;

interface

uses
  TvHelp;

type
  PHelpTopic = TvHelp.PHelpTopic;
  THelpTopic = TvHelp.THelpTopic;
  PHelpIndex = TvHelp.PHelpIndex;
  THelpIndex = TvHelp.THelpIndex;
  PHelpFile = TvHelp.PHelpFile;
  THelpFile = TvHelp.THelpFile;
  TCrossRefHandler = TvHelp.TCrossRefHandler;

implementation

end.
