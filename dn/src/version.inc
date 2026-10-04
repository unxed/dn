{ The include that the program VERSION of DN writes (tools of the original build: version.exe makes Version.inc with the
  name of the version, the date and the number); basics.pas includes it under DNPRG. Written by us with fixed
  values of the build for DOS. The date comes from the environment variable DN_BUILD_DATE, DN_BUILD_REV, DN_BUILD_TARGET that tools/build.sh sets (see there): the date of the last commit in numbers (UTC), the tag or the hash, the platform. }
  Const
     VersionName = '2.20 alpha/' + {$I %DN_BUILD_TARGET%};
     VersionDate = {$I %DN_BUILD_DATE%};
     VersionRev = {$I %DN_BUILD_REV%};
     VersionWord: AWord = $3B5E;
