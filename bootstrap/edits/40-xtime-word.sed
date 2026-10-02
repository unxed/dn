# xtime.pas: in VP Integer and Word are both 32 bits and a Word may be cast to Integer; in FPC Word is 16 bits.
# The only caller of DateToDMY passes the Word fields of Dos.DateTime, so the routine takes Words.
s/^procedure DateToDMY(Julian: Date; var Day, Month, Year: Integer);/procedure DateToDMY(Julian: Date; var Day, Month, Year: Word);/
s/DateToDMY(DTR\.D, Integer(Day), Integer(Month), Integer(Year));/DateToDMY(DTR.D, Day, Month, Year);/
s/Inc(Integer(DT2\.D), Days);/Inc(DT2.D, Days);/
