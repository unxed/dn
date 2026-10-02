{ What DN calls differently from tv/ (the interface part of the unit Views). }
const
  MaxViewWidth = 255;

type
  TPhase = TPhaseType;
  { A row of 16-bit cells (low byte: the character, high byte: the BIOS attribute): the buffer of Turbo Vision
    for Borland Pascal. It is written to the screen by WriteBufW/WriteLineW of TView (tv/DESIGN.md, 11c). }
  PDrawBuffer = ^TDrawBuffer;
  TDrawBuffer = array[0..MaxViewWidth - 1] of Word;
