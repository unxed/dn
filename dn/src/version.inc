{ The include that the program VERSION of DN writes (tools of the original build: version.exe makes Version.inc with the
  name of the version, the date and the number); basics.pas includes it under DNPRG. Fixed
  values of the build for DOS. The date comes from the environment variable DN_BUILD_DATE that tools/build.sh sets: by default the date of the last commit (the same sources, the same binary), DN_BUILD_DATE=now: the moment of the build. }
  Const
     VersionName = '2.14 beta/DPMI32';
     VersionDate = {$I %DN_BUILD_DATE%};
     VersionWord: AWord = $3B5E;
