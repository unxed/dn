# reason: (d) the modern compiler. ReadDiskInfo passes String[11] and String[8] variables to GetSerFileSys(var VolLab, FileSys: String)
# ($V-: allowed); the routine assigns `StrPas(DiskInfo.VolumeLabel)`, which is longer than 11 (the label has no #0, the file
# system name follows it): in VP the few bytes over went unnoticed, here they smash the stack (Ctrl-L: access violation).
# Full strings for the two variables.
s/^    VolumeLabel: String\[11\];/    VolumeLabel: String;/
s/^    FileSys: String\[8\]; { Rainbow }/    FileSys: String; { Rainbow }/
