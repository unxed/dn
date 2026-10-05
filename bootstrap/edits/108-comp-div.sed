# reason: (d) the modern compiler. Comp of VP became Int64 (edit 82); `/` on Comp gave a real that was rounded when it was
# assigned to a Comp, in FPC it is Extended, which is not assigned to Int64: integer division in filecopy.pas.
s/N := (N\*100)\/ToDo;/N := (N*100) div ToDo;/
s/Time := ((2\*ToDo-ToRead-ToWrite)\*CopyElapsedTime)\/(ToRead+ToWrite);/Time := ((2*ToDo-ToRead-ToWrite)*CopyElapsedTime) div (ToRead+ToWrite);/
s/Speed := 1000\*ToDo\/(CopyElapsedTime+Time);/Speed := 1000*ToDo div (CopyElapsedTime+Time);/
s/ZtoS(Speed\/1024)/ZtoS(Speed div 1024)/
s/GetPercent((ToWrite+ToRead)\/2)/GetPercent((ToWrite+ToRead) div 2)/
s/ToDoClusCopyTemp := \(SR\.FullSize\|P^\.Size\)\/BytesPerCluster;/ToDoClusCopyTemp := \1 div BytesPerCluster;/
# the same for FStr(X/1024) (FStr takes a Comp = Int64)
s/FStr(\([A-Za-z_][A-Za-z_0-9.^]*\)\/\([0-9][0-9]*\))/FStr(\1 div \2)/g
