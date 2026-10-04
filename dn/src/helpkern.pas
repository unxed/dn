{ HelpKern: the help kernel of DN is the help of our TV (tv/src/tvhelp.pas); this unit only gives the names that the
  code of DN uses (the types are the same types: regall registers them for the streams). }
{$mode objfpc}{$H-}
unit HelpKern;

interface

uses
  TvHelp;

type
  THelpTopic = TvHelp.THelpTopic;
  THelpIndex = TvHelp.THelpIndex;
  THelpFile = TvHelp.THelpFile;
  TCrossRefHandler = TvHelp.TCrossRefHandler;

implementation

end.
