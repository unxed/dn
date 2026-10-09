

{$DEFINE DEBUG}

 {$DEFINE NONBP}{$DEFINE LINEPOSIT}
 

 

 
  {$DEFINE USESYSUTILS}   {Cat: if you want to include the SysUtils unit or use exceptions; in the plugin version this has no effect}
  {.$DEFINE PLUGIN}        {Cat: plugin version}
  {.$DEFINE COLORER}       {Cat: Colorer plugin - may also be used outside the plugin version}
  {$DEFINE USELONGSTRING}  {Cat: use long strings in some places (in particular, in the editor)}
  {.$DEFINE USEANSISTRING} {Cat: use long strings everywhere ($H+); already compiles,     }
                           {     but does not work yet; I'll finish it if needed, which is unlikely  ;-) }
  { !!  when this parameter is changed, resources become incompatible  !! }
 


 
   {Cat: on exit check and write to the log how much memory was consumed and where}
  {.$DEFINE LOGOBJLOADSTORE} {Cat: write all Load and Store method calls to the log}
  {$DEFINE SHOWRC} {Cat: whether to append numeric error codes (RC) to error messages}
 


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
 
 
  {$DEFINE STRINGLFN} {enables a faster but memory-hungry algorithm for Windows LFN}
 
 {$DEFINE VPBETA}     {enables creation of DN.ERR on critical errors}
                      {affects how dn2cat.dll is linked in the Windows plugin version}
 {.$DEFINE OldCollection} {old assembler *Collection methods}
 {$DEFINE NoCallspcb} {warning! configs of versions compiled with and without NoCallspcb are incompatible!}
 {$DEFINE EAOP}       {Extended Attributes operations in OS/2}
                      {Security Attributes operations in WinNT}
 
 {$DEFINE QSORT}
 {.$DEFINE POGLSORT}
 {$DEFINE SpreadSheet}
 {$DEFINE PrintManager}
 {$DEFINE Printer}
 {$DEFINE PrintFromEditor}
 {.$DEFINE PKTVIEW} {compiles and works fine, but do we need it}
 {$DEFINE DisAsm}  {compiles and works fine, but do we need it}
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

{ Only TPW uses the W-prefixed unit; BP 7 uses the unprefixed unit }




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
