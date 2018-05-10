unit RedeemerAffineGeometry;

interface

uses
  Math, Types;

type
  TAffineTransformation = record
    a,b,c,d,e,f: Extended;
  end;

type
  TRealPoint = record
    x,y: Extended;
  end;

function RealPoint(const x,y: Extended): TRealPoint;
function AffineTransformation(const a,b,c,d: Extended; const e: Extended = 0; const f: Extended = 0): TAffineTransformation; overload;
function AffineTransformation(const Inner,Outer: TAffineTransformation): TAffineTransformation; overload;
function AffineTransformation(const Transformation: TAffineTransformation; const Vector: TRealPoint): TRealPoint; overload;
function AffineTransformation(const Transformation: TAffineTransformation; const Vector: TPoint): TPoint; overload;
function AffineTranslation(const x,y: Extended): TAffineTransformation;
function AffineRotation(const alpha: Extended): TAffineTransformation; overload;
function AffineRotation(const alpha,x,y: Extended): TAffineTransformation; overload;
function AffineScale(const x,y: Extended): TAffineTransformation;
function AffineSkewX(const x: Extended): TAffineTransformation;
function AffineSkewY(const y: Extended): TAffineTransformation;
//procedure AffineTranslateTransformation(var Inner: TAffineTransformation; const Outer: TRealPoint);
function AffineInverse(const Transformation: TAffineTransformation; out Inverse: TAffineTransformation): Boolean;
function RadAngle(const u,v: TRealPoint): Extended;
function FloatPositiveModulo(const Dividend: Extended; const Divisor: Extended): Extended;

implementation

function RealPoint(const x,y: Extended): TRealPoint;
begin
  Result.x := x;
  Result.y := y;
end;

function AffineTransformation(const a,b,c,d,e,f: Extended): TAffineTransformation; overload;
begin
  Result.a := a;
  Result.b := b;
  Result.c := c;
  Result.d := d;
  Result.e := e;
  Result.f := f;
end;

function AffineTransformation(const Inner,Outer: TAffineTransformation): TAffineTransformation;
begin
  Result.a := Outer.a*Inner.a + Outer.c*Inner.b;
  Result.b := Outer.b*Inner.a + Outer.d*Inner.b;
  Result.c := Outer.a*Inner.c + Outer.c*Inner.d;
  Result.d := Outer.b*Inner.c + Outer.d*Inner.d;
  Result.e := Outer.a*Inner.e + Outer.c*Inner.f + Outer.e;
  Result.f := Outer.b*Inner.e + Outer.d*Inner.f + Outer.f;
end;

function AffineTransformation(const Transformation: TAffineTransformation; const Vector: TRealPoint): TRealPoint;
begin
  Result.x := Transformation.a*Vector.x + Transformation.c*Vector.y + Transformation.e;
  Result.y := Transformation.b*Vector.x + Transformation.d*Vector.y + Transformation.f;
end;

function AffineTransformation(const Transformation: TAffineTransformation; const Vector: TPoint): TPoint;
begin
  Result.x := Round(Transformation.a*Vector.x + Transformation.c*Vector.y + Transformation.e);
  Result.y := Round(Transformation.b*Vector.x + Transformation.d*Vector.y + Transformation.f);
end;

function AffineTranslation(const x,y: Extended): TAffineTransformation;
begin
  Result := AffineTransformation(1, 0, 0, 1, x, y);
end;

function AffineRotation(const alpha: Extended): TAffineTransformation;
var
  rad: Extended;
begin
  rad := alpha / 180 * Pi;
  Result.a := cos(rad);
  Result.b := sin(rad);
  Result.c := -Result.b;
  Result.d := Result.a;
  Result.e := 0;
  Result.f := 0;
end;

function AffineRotation(const alpha,x,y: Extended): TAffineTransformation;
begin
  Result := AffineTransformation(AffineTranslation(-x, -y), AffineRotation(alpha));
  Result.e := Result.e + x;
  Result.f := Result.f + y;
end;

function AffineScale(const x,y: Extended): TAffineTransformation;
begin
  Result := AffineTransformation(x, 0, 0, y);
end;

function AffineSkewX(const x: Extended): TAffineTransformation;
var
  rad: Extended;
begin
  rad := x / 180 * Pi;
  Result := AffineTransformation(1, 0, Tan(rad), 1);
end;

function AffineSkewY(const y: Extended): TAffineTransformation;
var
  rad: Extended;
begin
  rad := y / 180 * Pi;
  Result := AffineTransformation(1, Tan(rad), 0, 1);
end;

{procedure AffineTranslateTransformation(var Inner: TAffineTransformation; const Outer: TRealPoint);
begin
  Inner.e := Inner.e + Outer.x;
  Inner.f := Inner.f + Outer.y;
end;}

function AffineInverse(const Transformation: TAffineTransformation; out Inverse: TAffineTransformation): Boolean;
var
  Determinant: Extended;
begin
  Determinant := Transformation.a * Transformation.d - Transformation.b * Transformation.c;
  Result := Determinant <> 0;
  if not Result then Exit;
  Inverse := AffineTransformation(Transformation.d / Determinant,
                                  -Transformation.b / Determinant,
                                  -Transformation.c / Determinant,
                                  Transformation.a / Determinant);
  with AffineTransformation(Inverse, RealPoint(Transformation.e, Transformation.f)) do
  begin
    Inverse.e := -x;
    Inverse.f := -y;
  end;
end;

function RadAngle(const u,v: TRealPoint): Extended;
function DotProduct(const u,v: TRealPoint): Extended;
begin
  Result := u.x * v.x + u.y * v.y;
end;
begin
  Result := DotProduct(u,v) / (sqrt(DotProduct(u,u)) * sqrt(DotProduct(v,v)));
  if Result >= 1 then // Gleitkomma-Ungenauigkeit vorbeugen
  Result := 0
  else if Result <= -1 then
  Result := Pi
  else
  Result := Arccos(Result);
  if u.x*v.y-u.y*v.x < 0 then
  Result := -Result;
end;

function FloatPositiveModulo(const Dividend: Extended; const Divisor: Extended): Extended;
begin
  // Modulo-Funktion, die mit negativen Dividenden und Gleitkommazahlen funktioniert
  //if Dividend < 0 then // negative Dividenden auflösen
  Result := Dividend + Ceil(-Dividend/Divisor) * Divisor
  //else
  //Result := Dividend + Ceil(-Dividend/Divisor);
end;

end.
