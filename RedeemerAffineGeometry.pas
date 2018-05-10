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
function AffineTransformation(const Transformation: TAffineTransformation; Vector: TRealPoint): TRealPoint; overload;
function AffineTransformation(const Transformation: TAffineTransformation; Vector: TPoint): TPoint; overload;
function AffineTranslation(const x,y: Extended): TAffineTransformation;
function AffineRotation(const alpha: Extended): TAffineTransformation; overload;
function AffineRotation(const alpha,x,y: Extended): TAffineTransformation; overload;
function AffineScale(const x,y: Extended): TAffineTransformation;
function AffineSkewX(const x: Extended): TAffineTransformation;
function AffineSkewY(const y: Extended): TAffineTransformation;

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

function AffineTransformation(const Transformation: TAffineTransformation; Vector: TRealPoint): TRealPoint;
begin
  Result.x := Transformation.a*Vector.x + Transformation.c*Vector.x + Transformation.e;
  Result.y := Transformation.b*Vector.y + Transformation.d*Vector.y + Transformation.f;
end;

function AffineTransformation(const Transformation: TAffineTransformation; Vector: TPoint): TPoint;
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
  Result.c := -sin(rad);
  Result.d := cos(rad);
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

end.
