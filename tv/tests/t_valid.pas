program t_valid;
{$I ../src/tvdefs.inc}
uses TvGeom, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp, TvMsgBox, TvValid;
{$I testlib.inc}

var
  App: PApplication;
  V: TValidator;
  F: PFilterValidator;
  Rg: PRangeValidator;
  Pic: PPXPictureValidator;
  L: PStringLookupValidator;
  M: TMemoryStream;
  PV: PValidator;
  SC: PStringCollection;
  S: ShortString;
  Num: LongInt;
  Used0: PtrUInt;
  P: PStr;

function Pics(const Pat: ShortString; Fill: Boolean; var S: ShortString): TPicResult;
var
  PV: PPXPictureValidator;
begin
  New(PV, Init(Pat, Fill));
  Result := PV^.Picture(S, Fill);
  Dispose(PV, Done);
end;

function PicOk(const Pat, Input: ShortString): Boolean;
var
  PV: PPXPictureValidator;
begin
  New(PV, Init(Pat, False));
  Result := PV^.IsValid(Input);
  Dispose(PV, Done);
end;

begin
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  New(App, Init);

  { the base validator accepts everything }
  V.Init;
  S := 'anything';
  Check(V.IsValid(S) and V.IsValidInput(S, False) and V.Validate(S), 'TValidator accepts everything');
  Check((V.Transfer(S, nil, vtGetData) = 0) and (V.Status = vsOk), 'it does not transfer and is ok');
  V.Done;

  { filter }
  New(F, Init('0123456789'));
  Check(F^.IsValid('12345') and F^.IsValid(''), 'TFilterValidator: digits are valid');
  Check(not F^.IsValid('12a45'), 'a letter is not');
  Dispose(F, Done);
  New(F, Init(['0'..'9', 'a'..'c']));
  Check(F^.IsValid('09ab') and not F^.IsValid('d') and (F^.ValidChars^ = '0123456789abc'), 'a filter made from a set');
  Dispose(F, Done);
  New(F, Init('0123456789'));
  S := '12';
  Check(F^.IsValidInput(S, False), 'input of digits');
  S := '1 2';
  Check(not F^.IsValidInput(S, False), 'input with a blank');
  MemClear;
  MemKey(kbEnter);
  Check(not F^.Validate('x'), 'Validate says no and shows the message box');
  Check(MemPending = 0, 'the message box took the key (Enter pressed OK)');
  Dispose(F, Done);

  { range }
  New(Rg, Init(1, 100));
  Check(Rg^.IsValid('50') and Rg^.IsValid('1') and Rg^.IsValid('100'), 'TRangeValidator: inside the range');
  Check(not Rg^.IsValid('0') and not Rg^.IsValid('101'), 'outside the range');
  Check(not Rg^.IsValid('') and not Rg^.IsValid('+'), 'no number');
  Check(Rg^.IsValid('+5'), 'a plus sign is allowed');
  Check(not Rg^.IsValid('-5'), 'a minus is not (the range is not negative)');
  S := '12';
  Check(Rg^.IsValidInput(S, False), 'input of digits');
  S := '1a';
  Check(not Rg^.IsValidInput(S, False), 'a letter is rejected');
  Check(Rg^.Transfer(S, @Num, vtGetData) = 0, 'no transfer without voTransfer');
  Rg^.Options := Rg^.Options or voTransfer;
  S := '42';
  Check(Rg^.Transfer(S, @Num, vtGetData) = SizeOf(LongInt), 'transfer: the size');
  Check(Num = 42, 'transfer: the value of the text');
  Num := 7;
  Check(Rg^.Transfer(S, @Num, vtSetData) = SizeOf(LongInt), 'transfer: set');
  Check(S = '7', 'transfer: the text of the value');
  MemClear;
  MemKey(kbEnter);
  Check(not Rg^.Validate('500'), 'a value out of the range: message box');
  Check(MemPending = 0, 'which took the key');
  Dispose(Rg, Done);
  New(Rg, Init(-10, 10));
  Check(Rg^.IsValid('-5') and Rg^.IsValid('-10') and not Rg^.IsValid('-11'), 'a signed range');
  Dispose(Rg, Done);

  { lookup }
  New(SC, Init(4, 4));
  P := NewStr('red'); SC^.Insert(P);
  P := NewStr('green'); SC^.Insert(P);
  New(L, Init(SC));
  Check(L^.IsValid('red') and L^.IsValid('green'), 'TStringLookupValidator: strings of the list');
  Check(not L^.IsValid('blue') and not L^.IsValid('Red'), 'others (case matters)');
  New(SC, Init(2, 2));
  P := NewStr('blue'); SC^.Insert(P);
  L^.NewStringList(SC);
  Check(L^.IsValid('blue') and not L^.IsValid('red'), 'NewStringList replaces the list (and frees the old one)');
  MemClear;
  MemKey(kbEnter);
  Check(not L^.Validate('x'), 'a string not in the list: message box');
  Dispose(L, Done);

  { pictures }
  Check(PicOk('###-####', '555-1234'), 'picture ###-####: a phone number');
  Check(not PicOk('###-####', '555-12'), 'incomplete is not valid');
  Check(not PicOk('###-####', '5x5-1234'), 'a letter in place of a digit');
  Check(not PicOk('###-####', '555-12345'), 'too long');
  Check(PicOk('???', 'abc') and not PicOk('???', 'ab1'), '? is a letter');
  Check(PicOk('&&', 'ab'), '& is a letter');
  S := 'ab';
  Check((Pics('&&', False, S) = prComplete) and (S = 'AB'), '& makes it upper case');
  S := 'ab1';
  Check((Pics('!!!', False, S) = prComplete) and (S = 'AB1'), '! upper-cases anything');
  Check(PicOk('@@@', 'a1 '), '@ takes any character');
  Check(PicOk('#;#', '1#') and not PicOk('#;#', '12'), '; takes the next character as it is');
  Check(PicOk('#[#]', '1') and PicOk('#[#]', '12'), '[ ] is optional');
  Check(not PicOk('#[#]', '123'), 'but not more');
  Check(PicOk('*#', '12345') and not PicOk('*#', ''), 'picture *#: any number of digits (empty input is prEmpty, not complete)');
  Check(PicOk('*3#', '123') and not PicOk('*3#', '12'), 'picture *3#: exactly three');
  Check(PicOk('{##},{???}', '12') and PicOk('{##},{???}', 'abc'), 'a comma separates alternatives');
  Check(not PicOk('{##},{???}', '1bc'), 'and an alternative is taken as a whole');
  Check(PicOk('##/##', '12/34'), 'a literal');
  Check(PicOk('##X##', '12x34'), 'literals match in any case');
  { fill }
  S := '12';
  Check((Pics('##/##/####', True, S) = prIncomplete) and (S = '12/'), 'autofill adds the literal that follows');
  S := '12/3';
  Pics('##/##/####', True, S);
  Check(S = '12/3', 'and stops before a digit');
  S := '12';
  Pics('##/##/####', False, S);
  Check(S = '12', 'without autofill nothing is added');
  S := '';
  Check(Pics('###', False, S) = prEmpty, 'empty input');
  S := '1';
  Check(Pics('###[', False, S) = prSyntax, 'a bad picture: prSyntax');
  S := '1';
  Check(Pics('##;', False, S) = prSyntax, 'a picture that ends with ;');
  New(Pic, Init('[', False));
  Check(Pic^.Status = vsSyntax, 'a bad picture sets the status');
  Dispose(Pic, Done);
  New(Pic, Init('##', True));
  Check((Pic^.Status = vsOk) and ((Pic^.Options and voFill) <> 0), 'autofill is an option');
  S := '5';
  Check(Pic^.IsValidInput(S, False), 'input that can be continued');
  S := 'a';
  Check(not Pic^.IsValidInput(S, False), 'input that cannot');
  MemClear;
  MemKey(kbEnter);
  Pic^.Error;
  Check(MemPending = 0, 'the picture error message box');
  Dispose(Pic, Done);

  { streams }
  RegisterType(RPXPictureValidator);
  RegisterType(RFilterValidator);
  RegisterType(RRangeValidator);
  RegisterType(RStringLookupValidator);
  M.Init(0, 1024);
  New(F, Init(['0'..'9']));
  New(Rg, Init(-5, 99));
  New(Pic, Init('{##}-{##}', True));
  M.Put(F);
  M.Put(Rg);
  M.Put(Pic);
  Dispose(F, Done);
  Dispose(Rg, Done);
  Dispose(Pic, Done);
  M.Seek(0);
  PV := PValidator(M.Get);
  Check((PV <> nil) and (TypeOf(PV^) = TypeOf(TFilterValidator)) and PFilterValidator(PV)^.IsValid('123') and
    not PFilterValidator(PV)^.IsValid('1a'), 'a filter validator through a stream');
  Dispose(PV, Done);
  PV := PValidator(M.Get);
  Check((PV <> nil) and (TypeOf(PV^) = TypeOf(TRangeValidator)) and (PRangeValidator(PV)^.Min = -5) and
    (PRangeValidator(PV)^.Max = 99), 'a range validator through a stream');
  Dispose(PV, Done);
  PV := PValidator(M.Get);
  Check((PV <> nil) and (TypeOf(PV^) = TypeOf(TPXPictureValidator)) and
    (PPXPictureValidator(PV)^.Pic^ = '{##}-{##}') and ((PV^.Options and voFill) <> 0), 'a picture validator through a stream');
  Dispose(PV, Done);
  M.Done;

  Dispose(App, Done);
  MemDone;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
