

{$DEFINE DEBUG}

 {$DEFINE NONBP}{$DEFINE LINEPOSIT}
 

 

 
  {$DEFINE USESYSUTILS}   {Cat: если хочется подключать модуль SysUtils или использовать механизм исключений; в плагинной версии ни на что не влияет}
  {.$DEFINE PLUGIN}        {Cat: плагинская версия}
  {.$DEFINE COLORER}       {Cat: плагин Colorer - может использоваться и не в плагинской версии тоже}
  {$DEFINE USELONGSTRING}  {Cat: использование длинных строк кое-где (в частности, в редакторе)}
  {.$DEFINE USEANSISTRING} {Cat: использование длинных строк везде ($H+); уже компилируется,     }
                           {     но ещё не работает; доделаю, если будет нужно, что вряд ли  ;-) }
  { !!  при изменении этого параметра ресурсы получаются несовместимыми  !! }
 


 
   {Cat: проверяем на выходе и пишем в лог, сколько памяти скушалось и в каком месте}
  {.$DEFINE LOGOBJLOADSTORE} {Cat: пишем в лог все вызовы методов Load и Store}
  {$DEFINE SHOWRC} {Cat: добавлять ли к сообщениям об ошибках числовые коды ошибок (RC)}
 


{.$DEFINE RegExp}
{$DEFINE Calendar}
{$DEFINE Game}
{$DEFINE TrashCan}
{$DEFINE CHCOL}
{$DEFINE SS}



{$DEFINE UUENCODE}
{$DEFINE UUDECODE}
{$DEFINE DBView}

 {$DEFINE NO_OVERLAY}
 {$DEFINE NOEXTRA}
 {$DEFINE BIT_32}
 {$DEFINE FILE_32}
 
 
  {.$DEFINE NOASM} {Cat:todo DPMI32}
  {$DEFINE USELFN}
  {$DEFINE DualName}
 
 
  {$DEFINE STRINGLFN} {включает более быстрый, но жрущий много памяти алгоритм работы с виндовыми LFN}
 
 {$DEFINE VPBETA}     {включает создание DN.ERR при критических ошибках}
                      {влияет на вариант подключения dn2cat.dll в виндовой плагинной версии}
 {.$DEFINE OldCollection} {старые ассемблерные методы *Collection}
 {$DEFINE NoCallspcb} {внимание! конфиги версий, скомпилённых с и без NoCallspcb несовместимы!}
 {$DEFINE EAOP}       {операции с Extended Attributes в OS/2}
                      {операции с Security Attributes в WinNT}
 
 {$Use32+}
 {$DEFINE QSORT}
 {.$DEFINE POGLSORT}
 {$DEFINE SpreadSheet}
 {$DEFINE PrintManager}
 {$DEFINE Printer}
 {$DEFINE PrintFromEditor}
 {.$DEFINE PKTVIEW} {нормально компилится и работает, но надо ли}
 {$DEFINE DisAsm}  {нормально компилится и работает, но надо ли}
 {$DEFINE PHONES}
 {$DEFINE ARVID}
 {.$DEFINE NETINFO}
 {$DEFINE FileNotify}
 
 {.$DEFINE CHDIRTIMER}
 {.$DEFINE SORTTIMER}
 {.$DEFINE COPYTIMER}






{.$DEFINE BANK}



{$DEFINE FULLOVR}
{$DEFINE FULLOVR2}
{$DEFINE VIEWSOVR}
{$DEFINE ADVANCEOVR}
{$DEFINE CollectOVR}
{$DEFINE MicroedOvr}
{$DEFINE VIDEOOVR}

{ Only TPW uses "WObjects"; BP 7 calls the same unit "Objects" }




{.$DEFINE PACKFILE}



 {Cat}

{.$IFDEF PLUGIN} {.$UNDEF GAME} {.$ENDIF} {Cat}
 {Cat}
 {Cat}
 {Cat}
 {Cat}
  {$H-}   {Cat}

 {AK155}
 {JO}

{$V-}
{$modeswitch nestedprocvars}
{$I-}
{$J+}
{$B-}
{$R-}
{$Q-}
{$PACKRECORDS 1}
