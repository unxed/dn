{ Include immediately after an implementation `uses` that pulls in SysUtils
  (or any unit that resurfaces System.PString).

  In Delphi mode FPC always has System.PString = ^AnsiString, even with -Sh-
  where String is ShortString. Once SysUtils appears in the implementation
  uses list, unqualified PString resolves to that AnsiString pointer and
  `S := PString(p)^` becomes fpc_ansistr_to_shortstr — AV on Message(@ShortString)
  (Enter on a non-executable, language menu, etc.).

  Defines.PString is ^ShortString; re-bind so DN code keeps short-string semantics. }
type
  PString = Defines.PString;
