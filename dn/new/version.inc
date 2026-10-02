{ The include that the program VERSION of DN writes (tools of the original build: version.exe makes Version.inc with the
  name of the version, the date and the number); advance.pas includes it under DNPRG. Fixed
  values of the build for DOS (the date is the date of the sources, not of the build: reproducible). }
  Const
     VersionName = '2.14 beta/DPMI32';
     VersionDate = 'Fri, 12 Jun 2025 at 00:00:00';
     VersionWord: AWord = $3B5E;
