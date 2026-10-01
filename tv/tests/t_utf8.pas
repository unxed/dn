program t_utf8;
{$I ../src/tvdefs.inc}
uses TvUtf8;
{$I testlib.inc}

var
  Buf: array[0..7] of Byte;

function Dec(const S: ShortString; out CP: LongWord; out Used: Integer): Boolean;
begin
  Result := Utf8Decode(@S[1], Length(S), CP, Used);
end;

function RoundTrip(CP: LongWord): Boolean;
var
  N, Used: Integer;
  Back: LongWord;
begin
  N := Utf8Encode(CP, @Buf[0]);
  Result := Utf8Decode(@Buf[0], N, Back, Used) and (Back = CP) and (Used = N);
end;

var
  CP: LongWord;
  Used: Integer;
begin
  { BytesLeft }
  Check(Utf8BytesLeft(Ord('a')) = 0, 'BytesLeft ASCII');
  Check(Utf8BytesLeft($C3) = 1, 'BytesLeft 2-byte lead');
  Check(Utf8BytesLeft($E4) = 2, 'BytesLeft 3-byte lead');
  Check(Utf8BytesLeft($F0) = 3, 'BytesLeft 4-byte lead');
  Check(Utf8BytesLeft($80) = 0, 'BytesLeft continuation');
  Check(Utf8BytesLeft($FF) = 0, 'BytesLeft invalid');

  { decoding valid sequences }
  Check(Dec('A', CP, Used) and (CP = $41) and (Used = 1), 'decode ASCII');
  Check(Dec(#$C3#$A9, CP, Used) and (CP = $E9) and (Used = 2), 'decode e-acute');
  Check(Dec(#$E4#$B8#$AD, CP, Used) and (CP = $4E2D) and (Used = 3), 'decode CJK');
  Check(Dec(#$F0#$9F#$98#$80, CP, Used) and (CP = $1F600) and (Used = 4), 'decode emoji');
  Check(Dec(#$C3#$A9'xyz', CP, Used) and (Used = 2), 'decode stops after one character');

  { invalid input }
  Check(not Dec(#$80, CP, Used) and (Used = 1), 'lone continuation byte');
  Check(not Dec(#$FF, CP, Used) and (Used = 1), 'invalid lead byte');
  Check(not Dec(#$C0#$80, CP, Used), 'overlong NUL');
  Check(not Dec(#$C1#$BF, CP, Used), 'overlong 2-byte');
  Check(not Dec(#$E0#$80#$80, CP, Used), 'overlong 3-byte');
  Check(not Dec(#$ED#$A0#$80, CP, Used), 'surrogate U+D800');
  Check(not Dec(#$F4#$90#$80#$80, CP, Used), 'above U+10FFFF');
  Check(not Dec(#$E4#$B8, CP, Used) and (Used = 2), 'truncated 3-byte sequence');
  Check(not Dec(#$E4'A', CP, Used) and (Used = 1), 'bad continuation resyncs at it');
  Check(not Utf8Decode(@Buf[0], 0, CP, Used) and (Used = 0), 'empty input');

  { encoding and round trip }
  Check(Utf8Encode($41, @Buf[0]) = 1, 'encode length 1');
  Check(Utf8Encode($E9, @Buf[0]) = 2, 'encode length 2');
  Check((Buf[0] = $C3) and (Buf[1] = $A9), 'encode e-acute bytes');
  Check(Utf8Encode($4E2D, @Buf[0]) = 3, 'encode length 3');
  Check(Utf8Encode($1F600, @Buf[0]) = 4, 'encode length 4');
  Check(RoundTrip($7F) and RoundTrip($80) and RoundTrip($7FF) and RoundTrip($800)
    and RoundTrip($FFFF) and RoundTrip($10000) and RoundTrip($10FFFF), 'round trip at the boundaries');

  { widths }
  Check(CharWidth(Ord('A')) = 1, 'width A');
  Check(CharWidth($E9) = 1, 'width e-acute');
  Check(CharWidth(0) = -1, 'width NUL is a control');
  Check(CharWidth(9) = -1, 'width TAB is a control');
  Check(CharWidth($7F) = -1, 'width DEL is a control');
  Check(CharWidth($85) = -1, 'width C1 control');
  Check(CharWidth($301) = 0, 'width combining acute');
  Check(CharWidth($200B) = 0, 'width zero width space');
  Check(CharWidth($200D) = 0, 'width zero width joiner');
  Check(CharWidth($AD) = 1, 'width soft hyphen');
  Check(CharWidth($1160) = 0, 'width Hangul jungseong filler');
  Check(CharWidth($4E2D) = 2, 'width CJK ideograph');
  Check(CharWidth($FF21) = 2, 'width fullwidth A');
  Check(CharWidth($3042) = 2, 'width hiragana');
  Check(CharWidth($AC00) = 2, 'width Hangul syllable');
  Check(CharWidth($1F600) = 2, 'width emoji');
  Check(CharWidth($FF61) = 1, 'width halfwidth ideographic full stop');
  Check(CharWidth($2500) = 1, 'width box drawing');
  Check(CharWidth($E000) = 1, 'width private use character');

  Finish;
end.
