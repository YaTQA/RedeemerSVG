unit RedeemerInheritablePNG;

interface

uses pngimage;

type TChunkIHDR2 = class(TChunkIHDR); // hole protected-Methode PrepareImageData

type TRedeemerInheritablePNG = class(TPNGImage)
  public
    procedure InitBlankNonPaletteImage(const ColorType, BitDepth: Cardinal; const cx, cy: Integer);
end;

implementation

{ TRedeemerInheritablePNG }

procedure TRedeemerInheritablePNG.InitBlankNonPaletteImage(const ColorType,
  BitDepth: Cardinal; const cx, cy: Integer);
var
  NewIHDR: TChunkIHDR2;
begin
  // CreateBlank-Methode ohne Create, Überprüfung auf Richtigkeit der Parameter
  // und ohne Unterstützung für Paletten
  InitializeGamma;
  BeingCreated := True;
  Chunks.Add(TChunkIEND);
  NewIHDR := Chunks.Add(TChunkIHDR2) as TChunkIHDR2;
  NewIHDR.ColorType := ColorType;
  NewIHDR.BitDepth := BitDepth;
  NewIHDR.Width := cx;
  NewIHDR.Height := cy;
  NewIHDR.PrepareImageData;
  Chunks.Add(TChunkIDAT);
  BeingCreated := False;
end;

end.
