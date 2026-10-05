{$mode objfpc}{$H-}
program t_flname;
uses Startup, basics, DNUtf8, TvUtf8;
{$I dntest.inc}
var
  S, Tab, R: String;
begin
  Utf8Enabled := True;
  S := #$D0#$90#$D0#$BB#$D1#$8C#$D1#$84#$D0#$B0;
  Check(ProxyToUtf8(Utf8ToProxy(S, Tab), Tab) = S, 'proxy roundtrip');
  R := FormatLongName(S, 25, 3, flnPadRight or flnAutoHideDot, nfmNull);
  Check(Pos(#$D0#$90, R) > 0, 'FormatLongName Cyrillic: ' + R);
  R := FormatLongName('abc.txt', 25, 3, flnPadRight or flnAutoHideDot, nfmNull);
  Check(Pos('txt', R) > 0, 'ascii ext');
  R := FormatLongName(#$E6#$97#$A5#$E6#$9C#$AC#$E8#$AA#$9E'.txt', 25, 3,
    flnPadRight or flnAutoHideDot, nfmNull);
  Check(Pos('txt', R) > 0, 'CJK ext col: ' + R);
  Finish;
end.
