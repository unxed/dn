{ fat32free: the second unit of the VP DPMI32 layer that DN lists in its uses (our unit). What DN takes from it
  besides realmode: DriveData, the buffer of INT 21h AX=7303h (the free space of a drive on FAT32). }
{$mode objfpc}{$H-}
unit fat32free;

interface

uses osdep, realmode;

type
  { the answer of INT 21h AX=7303h (Get Extended Free Space): RecSize is the first field }
  TDriveData = packed record
    RecSize: SmallWord;
    Version: SmallWord;
    SectorsPerCluster: LongInt;
    BytesPerSector: LongInt;
    AvailClusters: LongInt;
    TotalClusters: LongInt;
    AvailSectors: LongInt;
    TotalSectors: LongInt;
    AvailUnits: LongInt;
    TotalUnits: LongInt;
    Reserved: array[0..7] of Byte;
  end;

var
  DriveData: TDriveData;

implementation

end.
