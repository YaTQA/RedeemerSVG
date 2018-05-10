unit RedeemerScale;

interface

uses
  PNGImage, Graphics;

procedure PNGResize3to1(Source: TPngImage; Free: Boolean; var Result: TPngImage; CreateResult: Boolean);
procedure JoinAndDownscale(Chroma, Opacity, Result: TPNGImage; Free: Boolean = True);

implementation

uses
  RTLConsts, Consts;

procedure PNGResize3to1(Source: TPngImage; Free: Boolean; var Result: TPngImage; CreateResult: Boolean);
var
  i, j: Integer;
  Sum: Word;
  Scanlines: array[0..2] of PByteArray;
  TargetScanline: PByteArray;
  AlphaScanlines: array[0..2] of PByteArray;
  TargetAlphaScanline: PByteArray;
begin
  // Check if we have valid dimensions and valid color type
  if Source.Width mod 3 + Source.Height mod 3 > 0 then
  raise EInvalidGraphic.CreateFmt(SInvalidImageSize, []);
  if Source.Header.ColorType <> COLOR_RGBALPHA then
  raise EInvalidGraphic.CreateFmt(SInvalidImage, []);
  // Create new PNG
  if CreateResult then
  Result := TPngImage.CreateBlank(Source.Header.ColorType, 8, Source.Width div 3, Source.Height div 3);
  // Resize image data
  for i := 0 to Source.Height div 3 - 1 do
  begin
    Scanlines[0] := Source.Scanline[i * 3];
    Scanlines[1] := Source.Scanline[i * 3 + 1];
    Scanlines[2] := Source.Scanline[i * 3 + 2];
    AlphaScanlines[0] := Source.AlphaScanline[i * 3];
    AlphaScanlines[1] := Source.AlphaScanline[i * 3 + 1];
    AlphaScanlines[2] := Source.AlphaScanline[i * 3 + 2];
    TargetScanline := Result.Scanline[i];
    TargetAlphaScanline := Result.AlphaScanline[i];
    for j := 0 to Source.Width div 3 - 1 do
    begin
      sum := (AlphaScanlines[0][j*3] + AlphaScanlines[0][j*3+1] + AlphaScanlines[0][j*3+2] +
              AlphaScanlines[1][j*3] + AlphaScanlines[1][j*3+1] + AlphaScanlines[1][j*3+2] +
              AlphaScanlines[2][j*3] + AlphaScanlines[2][j*3+1] + AlphaScanlines[2][j*3+2]);
      if sum = 0 then
      TargetAlphaScanline[j] := 0
      else
      begin
        // top left pixel
        TargetScanline[j*3  ] := Round((Scanlines[0][j*9  ] * AlphaScanlines[0][j*3  ] + Scanlines[0][j*9+3] * AlphaScanlines[0][j*3+1] + Scanlines[0][j*9+6] * AlphaScanlines[0][j*3+2] +
                                        Scanlines[1][j*9  ] * AlphaScanlines[1][j*3  ] + Scanlines[1][j*9+3] * AlphaScanlines[1][j*3+1] + Scanlines[1][j*9+6] * AlphaScanlines[1][j*3+2] +
                                        Scanlines[2][j*9  ] * AlphaScanlines[2][j*3  ] + Scanlines[2][j*9+3] * AlphaScanlines[2][j*3+1] + Scanlines[2][j*9+6] * AlphaScanlines[2][j*3+2]) /
                                        (sum));
        TargetScanline[j*3+1] := Round((Scanlines[0][j*9+1] * AlphaScanlines[0][j*3  ] + Scanlines[0][j*9+4] * AlphaScanlines[0][j*3+1] + Scanlines[0][j*9+7] * AlphaScanlines[0][j*3+2] +
                                        Scanlines[1][j*9+1] * AlphaScanlines[1][j*3  ] + Scanlines[1][j*9+4] * AlphaScanlines[1][j*3+1] + Scanlines[1][j*9+7] * AlphaScanlines[1][j*3+2] +
                                        Scanlines[2][j*9+1] * AlphaScanlines[2][j*3  ] + Scanlines[2][j*9+4] * AlphaScanlines[2][j*3+1] + Scanlines[2][j*9+7] * AlphaScanlines[2][j*3+2]) /
                                        (sum));
        TargetScanline[j*3+2] := Round((Scanlines[0][j*9+2] * AlphaScanlines[0][j*3  ] + Scanlines[0][j*9+5] * AlphaScanlines[0][j*3+1] + Scanlines[0][j*9+8] * AlphaScanlines[0][j*3+2] +
                                        Scanlines[1][j*9+2] * AlphaScanlines[1][j*3  ] + Scanlines[1][j*9+5] * AlphaScanlines[1][j*3+1] + Scanlines[1][j*9+8] * AlphaScanlines[1][j*3+2] +
                                        Scanlines[2][j*9+2] * AlphaScanlines[2][j*3  ] + Scanlines[2][j*9+5] * AlphaScanlines[2][j*3+1] + Scanlines[2][j*9+8] * AlphaScanlines[2][j*3+2]) /
                                        (sum));
        TargetAlphaScanline[j] := Round(sum / 9);
      end;
    end;
  end;
  // Free old image if required
  if Free then
  Source.Free;
end;

procedure JoinAndDownscale(Chroma, Opacity, Result: TPNGImage; Free: Boolean = True);
var
  Scanline, Scanline2: pByteArray;
  x,y: Integer;
begin
  Chroma.CreateAlpha;
  for y := 0 to Opacity.Height - 1 do
  begin
    Scanline := Chroma.AlphaScanline[y];
    Scanline2 := Opacity.Scanline[y];
    for x := 0 to Opacity.Width - 1 do
    Scanline^[x] := Scanline2^[x];
  end;
  PNGResize3to1(Chroma, Free, Result, False);
  if Free then
  Opacity.Free;
end;

end.
