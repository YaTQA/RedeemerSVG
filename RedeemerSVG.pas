unit RedeemerSVG;

(* RedeemerSVG.TSVGImage
 * 0.5-beta
 * Copyright � 2017 Janni K. (redeemer.biz)
 *
 * Aufgrund des fr�hen Entwicklungsstadiums:
 * Lizenziert unter der Microsoft Reference Source License
 * Weiterverbreitung des Quelltextes und abgeleiteter Werke nur mit Erlaubnis
 *
 * Because of early development stage:
 * Licensed under Microsoft Reference Source License
 * Destribution of source code and derived works with my written consent
 *)

interface

uses
  PNGImage, Graphics, Sysutils, RedeemerAffineGeometry, RedeemerXML, Windows,
  RedeemerHypertextColors, RedeemerHypertextColorsCSS, Classes, RedeemerFloat,
  StrUtils, Kollegah, Math, RedeemerScale, RedeemerSVGHelpers, inifiles, Types,
  Generics.Collections, RedeemerInheritablePNG, Controls;

type
  TCustomUTF8Encoding = class(TUTF7Encoding)
  public
    constructor Create; override;
end;

type TRealRect = record
  Left, Top, Width, Height: Extended;
end;

type TFill = record
  Color: TColor;
  Opacity: Extended;
  Rule: Integer; // ALTERNATE, WINDING
end;

type TStroke = record
  Width: Extended; // negative Angaben: Prozent, bedeutet Prozent/100*sqrt((Breite�+H�he�)/2)
  Linecap: Cardinal;
  Linejoin: Cardinal;
  Opacity: Extended;
  Miterlimit: Extended;
  Color: TColor;
  DashArray: string;
end;

type TCSSFont = record
  Family: string;
  Style: Boolean; // Italic oder nicht
  Weight: Boolean; // Bold oder nicht
  Size: Extended;
end;

type TSVGContext = record
  Transformations: TAffineTransformation; // werden von au�en nach innen berechnet (Assoziativgesetz gilt), die innerste interne Transformation ist eine eigene Variable der Klasse
  LastViewBox: TRealRect;
  Fill: TFill;
  Stroke: TStroke;
  Font: TCSSFont;
  Display: Boolean;
  Opacity: Extended;
  PaintOrderStroke: Boolean; // Kontur zuerst ja/nein
end;

type TSizeCallbackEvent = procedure (const Viewport: TRealRect; var Dimensions: TRealPoint) of object;

type TSVGImage = class(TRedeemerInheritablePNG)
  private
    procedure InitDrawing();
    procedure FinishDrawing(const Context: TSVGContext);
    function  GetProperty(const Name: string; const CanAttribute: Boolean; const CanCSS: Boolean; out Value: string): Boolean;
    function  GetOnlyValue(const Attribute: string; out Value: Extended): Boolean; overload;
    function  GetOnlyValue(const Attribute: string; out Value: Extended; const PercentageMeasure: Extended): Boolean; overload;
    function  GetOnlyValueDef(const Attribute: string; const Default: Extended): Extended; overload;
    function  GetOnlyValueDef(const Attribute: string; const PercentageMeasure: Extended; const Default: Extended): Extended; overload;
    function  GetURLRef(const URL: string; const List: TDictionary<string,Integer>; out Value: Integer): Boolean;
    function  GetColorExt(const S: string; out Color: TColor): Boolean;
    procedure LoadBrush(const Fill: TFill);
    procedure LoadPen(const Stroke: TStroke; const Context: TSVGContext);
    procedure LoadFont(const Font: TCSSFont);
    procedure DrawPoly(Context: TSVGContext; const d: string);
    procedure HandleTag(const Context: TSVGContext; const Visible: Boolean);
    procedure HandleGroup2(Context: TSVGContext; const FullSVG: Boolean = False); // svg, g
    procedure HandleCircle(Context: TSVGContext; const IsEllipse: Boolean);
    procedure HandleRect(Context: TSVGContext);
    procedure HandleLine(Context: TSVGContext);
    procedure HandleText(Context: TSVGContext);
    procedure HandleUse(Context: TSVGContext);
    procedure HandleDefs();
    procedure ReadDimensions(var Dimensions: TRealPoint; const Context: TSVGContext);
    function  ReadViewbox(var ViewBox: TRealRect): Boolean;
    procedure ReadAspectRatio(out Align: TRealPoint; out Meet: Boolean);
    function  ReadPosition(): TRealPoint;
    function  MakeViewportTransformation(var Target: TAffineTransformation; const ViewBox: TRealRect; const Dimensions: TRealPoint; const Align: TRealPoint; const Meet: Boolean): TAffineTransformation;
    function  ReadStyle(var Context: TSVGContext): Boolean;
    procedure ReadFont(var Font: TCSSFont);
    procedure ReadStroke(var Stroke: TStroke);
    procedure ReadFill(var Fill: TFill);
    var
      CurrentStyle: TStyle;
      OpacityPNG: TPNGImage;
      ChromaPNG: TPNGImage;
      XML: TRedeemerXML;
      InnerTransformation: TAffineTransformation;
      Symbols: TDictionary<string,Integer>;
      Colors: TDictionary<string,Integer>;
      Recalls: TList<string>;
    const
      TempSupersample = 32;
      FinalSupersample = 3;
  public
    procedure LoadFromStream(Stream: TStream); override;
end;

function RealRect(Left, Top, Width, Height: Extended): TRealRect;

var
  SizeCallback: TSizeCallbackEvent = nil;

implementation

uses
  Forms; // f�r Screen.Fonts

function RealRect(Left, Top, Width, Height: Extended): TRealRect;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Width := Width;
  Result.Height := Height;
end;

{ TSVGImage }

procedure TSVGImage.DrawPoly(Context: TSVGContext; const d: string);
var
  p: TPath;
  LastEndpoint, LastBezier, NextEndpoint, FirstBezier, SecondBezier, Radii, DerotatedMidway, DerotatedCenter, Center, Dummy2: TRealPoint;
  Dummy, Angle, Theta, DeltaTheta: Extended;
  SweepFlag, LargeArcFlag: Boolean;
function ConditionalRelativeX(const f: Extended): Extended;
begin
  if AnsiChar(p.LastType) in ['a'..'z'] then
  Result := LastEndpoint.x + f
  else
  Result := f;
end;
function ConditionalRelativeY(const f: Extended): Extended;
begin
  if AnsiChar(p.LastType) in ['a'..'z'] then
  Result := LastEndpoint.y + f
  else
  Result := f;
end;
procedure DrawBezier(const SecondPoint: TRealPoint);
var
  Points: packed array[0..2] of tagPOINT;
begin
  Points[0].X := Round(FirstBezier.x * TempSupersample);
  Points[0].Y := Round(FirstBezier.y * TempSupersample);
  Points[1].X := Round(SecondPoint.x * TempSupersample);
  Points[1].Y := Round(SecondPoint.y * TempSupersample);
  Points[2].X := Round(LastEndpoint.x * TempSupersample);
  Points[2].Y := Round(LastEndpoint.y * TempSupersample);
  PolyBezierTo(ChromaPNG.Canvas.Handle, Points, 3);
end;
procedure DrawLineToEndpoint();
begin
  LineTo(ChromaPNG.Canvas.Handle,
         Round(LastEndpoint.x*TempSupersample),
         Round(LastEndpoint.y*TempSupersample));
end;
procedure MakeAbsolute(out Target: TRealPoint; const Source: TRealPoint);
begin
  Target.x := ConditionalRelativeX(Source.x);
  Target.y := ConditionalRelativeY(Source.y);
end;
procedure ForceGetPoint(out Point: TRealPoint);
begin
  if not p.GetNextNumber(Point.x) then Abort;
  if not p.GetNextNumber(Point.y) then Abort;
end;
procedure DrawArc(const ThetaEnd: Extended);
function EllipsePoint(const Theta: Extended): TRealPoint;
begin
  Result.x := Center.x + Radii.x * Cos(Angle) * Cos(Theta) - Radii.y * Sin(Angle) * Sin(Theta);
  Result.y := Center.y + Radii.x * Sin(Angle) * Cos(Theta) + Radii.y * Cos(Angle) * Sin(Theta);
end;
function EllipseDerive(const Theta: Extended): TRealPoint;
begin
  Result.x := -Radii.x * Cos(Angle) * Sin(Theta) - Radii.y * Sin(Angle) * Cos(Theta);
  Result.y := -Radii.x * Sin(Angle) * Sin(Theta) + Radii.y * Cos(Angle) * Cos(Theta);
end;
var
  PositionToIntersect: Extended;
begin
  // Position der Kontrollpunkte auf dem Weg zwischen einem Punkt auf dem Kreis und dem Punkt, an dem sich die Tangenten der beiden Punkte kreuzen, berechnen
  PositionToIntersect := sin(ThetaEnd - Theta) * (sqrt(4 + 3*sqr(tan((ThetaEnd - Theta) / 2))) - 1) / 3;
  FirstBezier := EllipsePoint(Theta);
  with EllipseDerive(Theta) do
  begin
    FirstBezier.x := FirstBezier.x + PositionToIntersect * x;
    FirstBezier.y := FirstBezier.y + PositionToIntersect * y;
  end;
  LastEndpoint := EllipsePoint(ThetaEnd);
  with EllipseDerive(ThetaEnd) do
  begin
    SecondBezier.x := LastEndpoint.x - PositionToIntersect * x;
    SecondBezier.y := LastEndpoint.y - PositionToIntersect * y;
  end;
  DrawBezier(SecondBezier);
end;
begin
  p := TPath.Create(d);
  LastEndpoint := RealPoint(0,0);
  try
    if not ReadStyle(Context) then Exit;
    InitDrawing;
    try
      while p.GetNextType() <> #4 do
      case Uppercase(p.LastType)[1] of
        // LineTo
        'L': begin
               ForceGetPoint(NextEndpoint);
               MakeAbsolute(LastEndpoint, NextEndpoint);
               DrawLineToEndpoint();
             end;
        // MoveTo
        'M': begin
               ForceGetPoint(NextEndpoint);
               MakeAbsolute(LastEndpoint, NextEndpoint);
               MoveToEx(ChromaPNG.Canvas.Handle,
                 Round(LastEndpoint.x*TempSupersample),
                 Round(LastEndpoint.y*TempSupersample),
                 nil);
             end;
        // Horizontal Line To
        'H': begin
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               DrawLineToEndpoint();
             end;
        // Vertical Line To
        'V': begin
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               DrawLineToEndpoint();
             end;
        // ClosePath
        'Z': CloseFigure(ChromaPNG.Canvas.Handle);
        // CubicB�zierCurveTo
        'C', 'S': begin
               if UpperCase(p.LastType) = 'S' then
               begin
                 // Punktspiegelung
                 FirstBezier.x := 2 * LastEndpoint.x - LastBezier.x;
                 FirstBezier.y := 2 * LastEndpoint.y - LastBezier.y;
               end
               else
               begin
                 ForceGetPoint(FirstBezier);
                 MakeAbsolute(FirstBezier, FirstBezier);
               end;
               ForceGetPoint(LastBezier);
               ForceGetPoint(NextEndpoint);
               MakeAbsolute(LastBezier, LastBezier);
               MakeAbsolute(LastEndpoint, NextEndpoint);
               DrawBezier(LastBezier);
             end;
        // QuadraticB�zierCurveTo
        'Q', 'T': begin
               if UpperCase(p.LastType) = 'T' then
               begin
                 // Punktspiegelung
                 LastBezier.x := 2 * LastEndpoint.x - LastBezier.x;
                 LastBezier.y := 2 * LastEndpoint.y - LastBezier.y;
               end
               else
               begin
                 ForceGetPoint(FirstBezier);
                 MakeAbsolute(LastBezier, FirstBezier);
               end;
               ForceGetPoint(NextEndpoint);
               // Umwandeln von quadratischer Kurve in kubische Kurve (laut deutscher Wikipedia)
               FirstBezier.x := LastEndpoint.x + 2 * (LastBezier.x - LastEndpoint.x) / 3;
               FirstBezier.y := LastEndpoint.y + 2 * (LastBezier.y - LastEndpoint.y) / 3;
               MakeAbsolute(LastEndpoint, NextEndpoint);
               SecondBezier.x := LastEndpoint.x + 2 * (LastBezier.x - LastEndpoint.x) / 3;
               SecondBezier.y := LastEndpoint.y + 2 * (LastBezier.y - LastEndpoint.y) / 3;
               DrawBezier(SecondBezier);
             end;
        // ArcTo
        'A': begin
               ForceGetPoint(Radii);
               if not p.GetNextNumber(Angle) then Abort;
               Angle := FloatPositiveModulo(Angle, 360); // Definition: Winkel mod 360
               if not p.GetNextNumber(Dummy) then Abort;
               LargeArcFlag := Dummy <> 0; // Definition: alles au�er 0 ist 1
               if not p.GetNextNumber(Dummy) then Abort;
               SweepFlag := Dummy <> 0;    // Definition: alles au�er 0 ist 1
               ForceGetPoint(NextEndpoint);
               MakeAbsolute(NextEndpoint, NextEndpoint);

               // Implementation nach https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes F.6.5
               // und https://mortoray.com/2017/02/16/rendering-an-svg-elliptical-arc-as-bezier-curves/
               DerotatedMidway := AffineTransformation(AffineRotation(-Angle),
                                  RealPoint((LastEndpoint.x - NextEndpoint.x)/2, (LastEndpoint.y - NextEndpoint.y)/2));
               Dummy := sqrt((DerotatedMidway.x*DerotatedMidway.x)/(Radii.x*Radii.x)+
                             (DerotatedMidway.y*DerotatedMidway.y)/(Radii.y*Radii.y));
               if Dummy > 1 then // Radius zu klein
               begin
                 Radii.x := Dummy * Radii.x;
                 Radii.y := Dummy * Radii.y;
               end;
               Dummy := radii.x*radii.x*DerotatedMidway.y*DerotatedMidway.y+radii.y*radii.y*DerotatedMidway.x*DerotatedMidway.x;
               Dummy := (radii.x*radii.x*radii.y*radii.y-Dummy)/Dummy;
               if Dummy > 0 then // Rundungsfehler korrigieren
               Dummy := sqrt(Dummy)
               else
               Dummy := 0;
               if SweepFlag = LargeArcFlag then
               Dummy := -Dummy;
               DerotatedCenter.x := Dummy*radii.x*DerotatedMidway.y/radii.y;
               DerotatedCenter.y := -Dummy*radii.y*DerotatedMidway.x/radii.x;
               Center := AffineTransformation(AffineRotation(Angle), DerotatedCenter);
               Center.x := Center.x + (LastEndpoint.x + NextEndpoint.x)/2;
               Center.y := Center.y + (LastEndpoint.y + NextEndpoint.y)/2;

               //OpacityPNG.Pixels[Round(Center.x*FinalSupersample),Round(Center.y*FinalSupersample)] := clWhite;

               Dummy2 := RealPoint((DerotatedMidway.x-DerotatedCenter.x)/Radii.x, (DerotatedMidway.y-DerotatedCenter.y)/Radii.y);
               Theta := RadAngle(RealPoint(1,0), Dummy2);
               DeltaTheta := FloatPositiveModulo(RadAngle(Dummy2,RealPoint((-DerotatedMidway.x-DerotatedCenter.x)/Radii.x, (-DerotatedMidway.y-DerotatedCenter.y)/Radii.y)), Pi * 2);
               if not SweepFlag then
               DeltaTheta := DeltaTheta - 2 * Pi;
               Dummy := 2 * Byte(SweepFlag) - 1; // Signum von DeltaTheta

               //Application.MessageBox(PChar(FloatToStr(Theta) + '/' + FloatToStr(DeltaTheta)), PChar('bla'), 0);
               Angle := Angle / 180 * pi; // Ab jetzt Bogenma�
               while Dummy * DeltaTheta > Pi/2 do
               begin
                 DrawArc(Theta+Dummy*Pi/2);
                 DeltaTheta := DeltaTheta - Dummy * Pi/2; // rechne Richtung 0
                 Theta := Theta + Dummy * Pi/2;
               end;
               DrawArc(Theta+DeltaTheta);

               LastEndpoint := NextEndpoint;
               DrawLineToEndpoint();
             end;
        // CentripetalCatmullRomTo (wird zu einer Geraden)
        'R': begin
               while p.GetNextNumber(Dummy) do // so lange Punkte laden, bis es nicht mehr geht, dann zum vorletzten(!) Punkt eine Linie zeichnen
               begin
                 NextEndpoint.x := NextEndpoint.y; // speichern der letzten vier Koordinaten, damit wir am Ende auf den vorletzten Punkt zugreifen k�nnen
                 NextEndpoint.y := LastEndPoint.x;
                 LastEndPoint.x := LastEndpoint.y;
                 LastEndPoint.y := Dummy;
               end;
               MakeAbsolute(LastEndpoint, NextEndpoint);
               DrawLineToEndpoint();
             end;
        // Bearing (wird ignoriert)
        'B': if not p.GetNextNumber(Dummy) then Abort;
      end;
      FinishDrawing(Context);
    except
      AbortPath(ChromaPNG.Canvas.Handle);
      raise Exception.Create('DEBUG: <path> failed at ' + IntToStr(p.Position) + ' on input:' + #13#10 + d);
    end;
  finally
    p.Free;
  end;
end;

procedure TSVGImage.FinishDrawing(const Context: TSVGContext);
begin
  LoadBrush(Context.Fill);
  LoadPen(Context.Stroke, Context);
  EndPath(ChromaPNG.Canvas.Handle);
  Kollegah.Bosstransformation(ChromaPNG.Canvas.Handle, [ChromaPNG.Canvas.Handle, OpacityPNG.Canvas.Handle], AffineTransformation(InnerTransformation, Context.Transformations), Context.PaintOrderStroke);
end;

function TSVGImage.GetColorExt(const S: string; out Color: TColor): Boolean;
var
  i: Integer;
begin
  if StartsText('url(#', s) then // Farbreferenz
  begin
    Result := GetURLRef(S, Colors, i);
    if Result then
    Color := TColor(i);
  end
  else
  Result := HTMLToColor(S, Color, CSSColors);
end;

function TSVGImage.GetOnlyValue(const Attribute: string; out Value: Extended): Boolean;
var
  s: string;
begin
  Result := XML.GetAttribute(Attribute, s);
  if Result then
  Result := TCoordinates.GetOnlyValue(s, Value);
end;

function TSVGImage.GetOnlyValue(const Attribute: string; out Value: Extended; const PercentageMeasure: Extended): Boolean;
var
  s: string;
begin
  Result := XML.GetAttribute(Attribute, s);
  if Result then
  Result := TCoordinates.GetOnlyValue(s, Value, PercentageMeasure);
end;

function TSVGImage.GetOnlyValueDef(const Attribute: string; const Default: Extended): Extended;
var
  s: string;
  b: Boolean;
begin
  b := XML.GetAttribute(Attribute, s);
  if b then
  Result := TCoordinates.GetOnlyValueDef(s, Default)
  else
  Result := Default;
end;

function TSVGImage.GetOnlyValueDef(const Attribute: string; const PercentageMeasure: Extended; const Default: Extended): Extended;
var
  s: string;
  b: Boolean;
begin
  b := XML.GetAttribute(Attribute, s);
  if b then
  Result := TCoordinates.GetOnlyValueDef(s, PercentageMeasure, Default)
  else
  Result := Default;
end;

function TSVGImage.GetProperty(const Name: string; const CanAttribute, CanCSS: Boolean; out Value: string): Boolean;
begin
  Result := False;
  if CanCSS then
  Result := CurrentStyle.GetProperty(Name, Value);
  if not Result and CanAttribute then
  Result := XML.GetAttribute(Name, Value);
end;

function TSVGImage.GetURLRef(const URL: string; const List: TDictionary<string,Integer>; out Value: Integer): Boolean;
var
  s, s2: string;
begin
  Result := False;
  if List = Colors then
  begin
    if not TStyleSplitter.GetBracket(URL, s, s2) then Exit;
    if not SameText(s, 'url') then Exit;
  end
  else
  s2 := URL;

  if StartsStr('#', s2) then
  begin
    Delete(s2, 1, 1);
    Result := List.ContainsKey(s2);
    if Result then
    Value := List[s2];
  end;
end;

procedure TSVGImage.HandleCircle(Context: TSVGContext; const IsEllipse: Boolean);
var
  rx, ry, cx, cy: Extended;
begin
  if not ReadStyle(Context) then Exit;

  // Koordinaten laden
  if IsEllipse then
  begin
    if not GetOnlyValue('rx',rx,Context.LastViewBox.Width) then Exit;
    if not GetOnlyValue('ry',ry,Context.LastViewBox.Height) then Exit;
  end
  else
  begin
    if not GetOnlyValue('r',rx,(sqrt((sqr(Context.LastViewBox.Width) + sqr(Context.LastViewBox.Height)) / 2))) then Exit;
    ry := rx;
  end;

  begin
    InitDrawing;
    cx := GetOnlyValueDef('cx',Context.LastViewBox.Width,0);
    cy := GetOnlyValueDef('cy',Context.LastViewBox.Height,0);
    Ellipse(ChromaPNG.Canvas.Handle,
      Integer(Round((cx-rx)*TempSupersample)),
      Integer(Round((cy-ry)*TempSupersample)),
      Integer(Round((cx+rx)*TempSupersample)),
      Integer(Round((cy+ry)*TempSupersample))
    );
    FinishDrawing(Context);
  end;
end;

procedure TSVGImage.HandleDefs();
var
  NextStopName: string;
  i: TColor;
begin
  if XML.IsSelfClosing then Exit; // Inkscape, was machst du f�r einen Bl�dsinn?
  NextStopName := '';
  while XML.GoToAndGetNextTag do
  begin
    // Gruppen m�ssen bearbeitet werden, damit die Sichtbarkeit korrekt f�r alle Unterelement gilt, Rest nicht
    if XML.CurrentTag = '/defs' then
    Exit
    else
    if XML.CurrentTag = 'symbol' then
    Symbols.AddOrSetValue(XML.GetAttributeDef('id', ''), XML.Position)
    else
    if (XML.CurrentTag = 'radialgradient') or (XML.CurrentTag = 'lineargradient') then
    NextStopName := XML.GetAttributeDef('id', '')
    else
    if (XML.CurrentTag = 'stop') and (NextStopName <> '') then
    if RedeemerHypertextColors.HTMLToColor(XML.GetAttributeDef('stop-color', ''), i, CSSColors) then
    begin
      Colors.Add(NextStopName, Integer(i));
      NextStopName := '';
    end
    else
    else
    if XML.CurrentTag = 'solidcolor' then
    if RedeemerHypertextColors.HTMLToColor(XML.GetAttributeDef('solid-color', ''), i, CSSColors) then
    begin
      Colors.Add(XML.GetAttributeDef('id', ''), Integer(i));
      NextStopName := '';
    end;
  end;
end;

procedure TSVGImage.HandleGroup2(Context: TSVGContext; const FullSVG: Boolean = False);
var
  EndTag: string;
  Dimensions, Align: TRealPoint;
  Visible, Meet: Boolean;
begin
  EndTag := '/' + XML.CurrentTag;
  Visible := ReadStyle(Context);
  if FullSVG then
  begin
    ReadDimensions(Dimensions, Context);
    ReadAspectRatio(Align, Meet);
    if ReadViewbox(Context.LastViewBox) then
    MakeViewportTransformation(Context.Transformations, Context.LastViewBox, Dimensions, Align, Meet);
    with ReadPosition do
    Context.Transformations := AffineTransformation(AffineTranslation(x,y), Context.Transformations);
  end;
  while XML.GoToAndGetNextTag do
  begin
    if XML.CurrentTag = EndTag then
    Exit
    else
    HandleTag(Context, Visible);
  end;
end;

procedure TSVGImage.HandleTag(const Context: TSVGContext; const Visible: Boolean);
var
  d: string;
begin
  // Diese Methode entscheidet je nach Tag, welche Behandlungsroutine aufgerufen werden muss
  // Gruppen m�ssen immer bearbeitet werden, damit jedes Element einmal bearbeitet wird
  if (XML.CurrentTag = 'g') or (XML.CurrentTag = 'symbol') then
  HandleGroup2(Context)
  else
  if XML.CurrentTag = 'defs' then
  HandleDefs()
  else
  if XML.CurrentTag = 'use' then
  HandleUse(Context)
  else
  if XML.CurrentTag = 'svg' then
  HandleGroup2(Context, True)
  else
  // falls gezeichnet werden muss, bearbeite sichtbare Objekte, die keine (zu iterierenden) Kinder haben werden
  if Visible then
  if XML.CurrentTag = 'rect' then
  HandleRect(Context)
  else
  if XML.CurrentTag = 'circle' then
  HandleCircle(Context, False)
  else
  if XML.CurrentTag = 'ellipse' then
  HandleCircle(Context, True)
  else
  if XML.CurrentTag = 'line' then
  HandleLine(Context)
  else
  if XML.CurrentTag = 'polyline' then
  begin
    if XML.GetAttribute('points', d) then
    DrawPoly(Context, 'M' + d);
  end
  else
  if XML.CurrentTag = 'polygon' then
  begin
    if XML.GetAttribute('points', d) then
    DrawPoly(Context, 'M' + d + 'Z');
  end
  else
  if XML.CurrentTag = 'path' then
  begin
    if XML.GetAttribute(string('d'), d) then // wird ohne die sinnlose Typumwandlung manchmal aus irgendwelchen Gr�nden angekreidet
    DrawPoly(Context, d);
  end
  else
  if XML.CurrentTag = 'text' then
  HandleText(Context);
end;

procedure TSVGImage.HandleLine(Context: TSVGContext);
begin
  if not ReadStyle(Context) then Exit;
  InitDrawing;
  MoveToEx(ChromaPNG.Canvas.Handle,
    Round(GetOnlyValueDef('x1',Context.LastViewBox.Width,0)*TempSupersample),
    Round(GetOnlyValueDef('y1',Context.LastViewBox.Height,0)*TempSupersample),
    nil);
  LineTo(ChromaPNG.Canvas.Handle,
    Round(GetOnlyValueDef('x2',Context.LastViewBox.Width,0)*TempSupersample),
    Round(GetOnlyValueDef('y2',Context.LastViewBox.Height,0)*TempSupersample));
  FinishDrawing(Context);
end;

procedure TSVGImage.HandleRect(Context: TSVGContext);
var
  x,y,h,w,rx,ry: Extended;
begin
  if not ReadStyle(Context) then Exit;
  if GetOnlyValue('width',w,Context.LastViewBox.Width) then
  if GetOnlyValue('height',h,Context.LastViewBox.Height) then
  begin
    InitDrawing;
    x := GetOnlyValueDef('x',Context.LastViewBox.Width,0);
    y := GetOnlyValueDef('y',Context.LastViewBox.Height,0);
    // Wird nur ein Rundungs-Wert angegeben, erh�lt der andere dessen Wert - inklusive der Bezugsnorm f�r Prozentangaben!
    if GetOnlyValue('rx',rx,Context.LastViewBox.Width) then
    ry := GetOnlyValueDef('ry',Context.LastViewBox.Height,rx)
    else
    begin
      ry := GetOnlyValueDef('ry',Context.LastViewBox.Height,0);
      rx := ry;
    end;

    RoundRect(ChromaPNG.Canvas.Handle,
      Integer(Round(x*TempSupersample)),
      Integer(Round(y*TempSupersample)),
      Integer(Round((x+w)*TempSupersample)),
      Integer(Round((y+h)*TempSupersample)),
      Integer(Round(rx*2*TempSupersample)), // GDI benutzt den Durchmesser, SVG den Radius
      Integer(Round(ry*2*TempSupersample))
    );
    FinishDrawing(Context);
  end;
end;

procedure TSVGImage.HandleText(Context: TSVGContext);
var
  x,y: TCoordinates;
  x2,y2: Extended;
  s,s2: string;
  i, count: Integer;
begin
  if not ReadStyle(Context) then Exit;

  // Attribute/Eigenschaften laden
  x := TCoordinates.Create(XML.GetAttributeDef('x','0'));
  y := TCoordinates.Create(XML.GetAttributeDef('y','0'));
  try
    SetTextAlign(ChromaPNG.Canvas.Handle, TA_LEFT or TA_BASELINE);
    if XML.GetAttribute('text-anchor', s) then
    if s = 'end' then
    SetTextAlign(ChromaPNG.Canvas.Handle, TA_RIGHT or TA_BASELINE)
    else
    if s = 'middle' then
    SetTextAlign(ChromaPNG.Canvas.Handle, TA_CENTER or TA_BASELINE);
    // Text zeichnen
    s := XML.GetInnerTextAndSkip;
    if s <> '' then
    begin
      InitDrawing();
      LoadFont(Context.Font);

      // Z�hlen, in wievielen Einzelteilen der Text gerendet werden muss
      count := 0;
      while x.GetNextCoordinate(1, x2) do // konkreter Wert f�r Prozentwert derzeit egal
      inc(count);
      x.Position := 1; // Position des Koordinaten-Splitters f�rs tats�chliche Rendern zur�cksetzen

      // Einzelteile rendern
      i := 0;
      while x.GetNextCoordinate(Context.LastViewBox.Width, x2) do
      begin
        inc(i);
        if i < count then
        begin
        s2 := Copy(s, 1, 1); // soll nur verhindern, �ber das Ende hinaus zu lesen, daher keine Verwendung von s[1]
        Delete(s, 1, 1);
        end
        else
        s2 := s;
        y.GetNextCoordinate(Context.LastViewBox.Height, y2); // wenn nicht, dann halt nicht (bleibt unver�ndert)
        ExtTextOut(ChromaPNG.Canvas.Handle, Integer(Round(x2*TempSupersample)), Integer(Round(y2*TempSupersample)), 0, nil, PChar(s2), Length(s2), nil);
      end;
      FinishDrawing(Context);
    end;
  finally
    x.Free;
    y.Free;
  end;
end;

procedure TSVGImage.HandleUse(Context: TSVGContext);
var
  OldPos, NewPos, StackIndex: Integer;
  s: string;
  Dimensions, Align, Position: TRealPoint;
  Meet: Boolean;
begin
  // Eigenschaften des aufrufenden use-Tags lesen
  ReadStyle(Context);

  OldPos := XML.Position;
  if XML.GetAttribute('xlink:href', s) then
  if GetURLRef(s, Symbols, NewPos) then
  if not Recalls.Contains(s) then // Endlosschleife verhindern
  try
    // Viewbox-relevante Daten aus use-Tag lesen
    ReadDimensions(Dimensions, Context); // wird verworfen, wenn es keine Viewbox gibt
    Position := ReadPosition;

    // Zu Definition springen
    XML.Position := NewPos;
    StackIndex := Recalls.Add(s);
    XML.LoadTagName();
    XML.LoadAttributes();

    // Tag der Definition bearbeiten
    if XML.CurrentTag = 'symbol' then
    begin
      // Viewbox-relevante Daten aus symbol-Tag lesen
      ReadAspectRatio(Align, Meet);
      if ReadViewbox(Context.LastViewBox) then
      MakeViewportTransformation(Context.Transformations, Context.LastViewBox, Dimensions, Align, Meet);
    end;
    // In jedem Fall kann aber x und y angewendet werden
    // Dies wird eigentlich VOR der Translation (oben in ReadStyle geladen) angewandt,
    // aber durch die Schachtelbarkeit von Elementen berechnet RedeemerSVG Transformationen von au�en nach innen (Assoziativgesetz)
    Context.Transformations := AffineTransformation(AffineTranslation(Position.x,Position.y), Context.Transformations);

    HandleTag(Context, True);
    Recalls.Delete(StackIndex);
  finally
    XML.Position := OldPos;
    //XML.LoadAttributes und XML.LoadTagName nicht n�tig, da auf Tag-Name und Attribute nicht mehr zugegriffen wird (�bergeordnete Schleife springt sofort zum n�chsten Tag)
  end;
end;

procedure TSVGImage.InitDrawing;
begin
  SetBkMode(OpacityPNG.Canvas.Handle, Windows.TRANSPARENT);
  BeginPath(OpacityPNG.Canvas.Handle);
  SetBkMode(ChromaPNG.Canvas.Handle, Windows.TRANSPARENT);
  BeginPath(ChromaPNG.Canvas.Handle);
end;

procedure TSVGImage.LoadFont(const Font: TCSSFont);
begin
  ChromaPNG.Canvas.Font.Height := -Round(Font.Size * TempSupersample);
  ChromaPNG.Canvas.Font.Name := Font.Family;
  ChromaPNG.Canvas.Font.Style := [];
  if Font.Style then
  ChromaPNG.Canvas.Font.Style := ChromaPNG.Canvas.Font.Style + [fsItalic];
  if Font.Weight then
  ChromaPNG.Canvas.Font.Style := ChromaPNG.Canvas.Font.Style + [fsBold];
end;

procedure TSVGImage.LoadFromStream(Stream: TStream);
var
  sl: TStringList;
  Context: TSVGContext;
  Meet: Boolean;
  Encoding: TCustomUTF8Encoding;
  Align, Dimensions: TRealPoint;
  StartPos: Integer;
  ID: string;
begin
  sl := TStringList.Create;
  Encoding := TCustomUTF8Encoding.Create;
  try
    sl.LoadFromStream(Stream, Encoding);
    XML := TRedeemerXML.Create(sl.Text);
  finally
    sl.Free;
    Encoding.Free;
  end;
  Colors := Generics.Collections.TDictionary<string,Integer>.Create;
  Symbols := Generics.Collections.TDictionary<string,Integer>.Create;
  Recalls := Generics.Collections.TList<string>.Create;
  try
    while XML.GoToAndGetNextTag do
    if XML.CurrentTag = 'svg' then
    begin
      // Erstmal Gr��e lesen
      Context.LastViewBox := RealRect(0, 0, 300, 300);
      //ReadPosition;
      ReadAspectRatio(Align, Meet);
      if ReadViewbox(Context.LastViewBox) then
      ReadDimensions(Dimensions, Context)
      else
      begin
        ReadDimensions(Dimensions, Context);
        Context.LastViewBox.Width := Dimensions.x;
        Context.LastViewBox.Height := Dimensions.y;
      end;
      //Context.LastViewBox := RealRect(0,0,Dimensions.x,Dimensions.y);

      // Gr��e vom Benutzer best�tigen lassen
      if Assigned(SizeCallback) then
      SizeCallback(Context.LastViewBox, Dimensions);

      // Restlichen Kontext initialisieren
      Context.Fill.Rule := WINDING;
      Context.Fill.Opacity := 1;
      Context.Fill.Color := clBlack;
      Context.Stroke.Color := clNone;
      Context.Stroke.Width := 1;
      Context.Stroke.Linecap := PS_ENDCAP_FLAT;
      Context.Stroke.Linejoin := PS_JOIN_MITER;
      Context.Stroke.Opacity := 1;
      Context.Stroke.Miterlimit := 4;
      Context.Font.Family := 'Times New Roman';
      Context.Font.Size := 16;
      Context.Font.Weight := False;
      Context.Font.Style := False;
      Context.Opacity := 1;
      Context.Display := True;
      Context.PaintOrderStroke := False;
      // Standard-Bosstransformation: tempor�res Supersampling r�ckg�ngig machen, Koordinatensystem umwandeln
      InnerTransformation := AffineScale(1 / TempSupersample, 1 / TempSupersample);
      Context.Transformations := AffineTransformation(FinalSupersample, 0, 0, FinalSupersample, -0.5, -0.5);

      // Transformation in den richtigen Zeichenbereich
      MakeViewportTransformation(Context.Transformations, Context.LastViewBox, Dimensions, Align, Meet); // keine Position im Wurzel-Tag

      // Zeichenfl�chen initialisieren (urspr�nglicher Join-Algorithmus hatte RGB bei Opacity, war das f�r Rastergrafiken n�tig?)
      ChromaPNG := TPngImage.CreateBlank(COLOR_RGB, 8, Round(Dimensions.x) * FinalSupersample, Round(Dimensions.y) * FinalSupersample);
      OpacityPNG := TPngImage.CreateBlank(COLOR_GRAYSCALE, 8, Round(Dimensions.x) * FinalSupersample, Round(Dimensions.y) * FinalSupersample);

      // Definitionen laden
      StartPos := XML.Position;
      while XML.GoToAndGetNextTag do
      if XML.GetAttribute('id', ID) then
      Symbols.Add(ID, XML.Position);

      // Reset
      XML.Position := StartPos;
      XML.Done := False;
      XML.LoadTagName;
      XML.LoadAttributes;
      HandleGroup2(Context);

      // Zusammenlegen der Bilder
      InitBlankNonPaletteImage(COLOR_RGBALPHA, 8, Round(Dimensions.x), Round(Dimensions.y));
      JoinAndDownscale(ChromaPNG, OpacityPNG, Self, True);

      Exit; // nur erstes <svg> in der Wurzel bearbeiten
    end;
  finally
    XML.Free;
    Symbols.Free;
    Colors.Free;
    Recalls.Free;
  end;
end;

procedure TSVGImage.LoadBrush(const Fill: TFill);
begin
  ChromaPNG.Canvas.Brush.Color := Fill.Color; // wenn man das nach Style setzt, geht das nicht
  if (Fill.Color = clNone) or (Fill.Opacity < 0.2) then
  ChromaPNG.Canvas.Brush.Style := bsClear
  else
  ChromaPNG.Canvas.Brush.Style := bsSolid;
  SetPolyFillMode(ChromaPNG.Canvas.Handle, Fill.Rule);
  OpacityPNG.Canvas.Brush.Color := clWhite;
  OpacityPNG.Canvas.Brush.Style := ChromaPNG.Canvas.Brush.style;
  SetPolyFillMode(OpacityPNG.Canvas.Handle, Fill.Rule);
end;

procedure TSVGImage.LoadPen(const Stroke: TStroke; const Context: TSVGContext);
var
  Flags: Cardinal;
  Width: Integer;
  Brush: tagLOGBRUSH;
  Dashes: TCoordinates;
  DashData: packed array of DWord;
  f, PercentageScale, Scale: Extended;
  Miter: Single;
begin
  if (Stroke.Color = clNone) or (Stroke.Width = 0) or (Stroke.Opacity < 0.2) then
  Flags := PS_NULL // Width kann nicht auf weniger als 1 gesetzt werden, weder mit ExtCreatePen noch mit TPen
  else
  Flags := PS_SOLID;

  PercentageScale := sqrt((sqr(Context.LastViewBox.Width) + sqr(Context.LastViewBox.Height)) / 2);
  Scale := sqrt((sqr(Context.Transformations.a)+sqr(Context.Transformations.b)+sqr(Context.Transformations.c)+sqr(Context.Transformations.d))/2);

  if Flags <> PS_NULL then
  begin
    Width := Round(TCoordinates.MakeAbsolute(PercentageScale, Stroke.Width)*Scale);
    if Stroke.DashArray <> 'none' then
    begin
      Dashes := TCoordinates.Create(Stroke.DashArray);
      try
        while Dashes.GetNextCoordinate(PercentageScale, f) do
        begin
          SetLength(DashData, Length(DashData) + 1);
          DashData[High(DashData)] := Round(f*Scale);
          Flags := PS_USERSTYLE;
          if Length(DashData) = 16 then
          Break; // undokumente Einschr�nkung von Length(DashData) auf <= 16 in GDI
        end;
        // Deaktivierung eines Sonderfalls in GDI, das ein ungerade lange Dasharrays bei ungerade Wiederholungen invertiert durchl�uft
        if Length(DashData) mod 2 = 1 then
        begin
          SetLength(DashData, Length(DashData) + 1);
          DashData[High(DashData)] := 0;
        end;
      finally
        Dashes.Free;
      end;
    end;
  end
  else
  Width := 0;

  Brush.lbStyle := BS_SOLID;
  Brush.lbColor := Stroke.Color;
  Miter := Stroke.Miterlimit * 0.9999999; // GDI schneidet AB der Gehrungsgrenze ab, SVG schneider �BER der Grenze ab
  DeleteObject(ChromaPNG.Canvas.Pen.Handle);
  ChromaPNG.Canvas.Pen.Handle := ExtCreatePen(PS_GEOMETRIC or Flags or Stroke.Linecap or Stroke.Linejoin, Width, Brush, Length(DashData), DashData);
  SetMiterLimit(ChromaPNG.Canvas.Handle, Miter, nil);
  Brush.lbColor := clWhite;
  DeleteObject(OpacityPNG.Canvas.Pen.Handle);
  OpacityPNG.Canvas.Pen.Handle := ExtCreatePen(PS_GEOMETRIC or Flags or Stroke.Linecap or Stroke.Linejoin, Width, Brush, Length(DashData), DashData);
  SetMiterLimit(OpacityPNG.Canvas.Handle, Miter, nil);
end;

function TSVGImage.MakeViewportTransformation(var Target: TAffineTransformation; const ViewBox: TRealRect; const Dimensions: TRealPoint; const Align: TRealPoint; const Meet: Boolean): TAffineTransformation;
var
  Scale: Extended;
begin
  if Align.x = -1 then
  Target := AffineTransformation(
            AffineScale(Dimensions.x / ViewBox.Width, Dimensions.y / ViewBox.Height),
            Target)
  else
  begin
  if Meet then
  Scale := Min(Dimensions.x / ViewBox.Width, Dimensions.y / ViewBox.Height)
  else
  Scale := Max(Dimensions.x / ViewBox.Width, Dimensions.y / ViewBox.Height);
  Target := AffineTransformation(
            AffineTransformation(Scale, 0, 0, Scale,
            (Dimensions.x - ViewBox.Width * Scale) * Align.x,
            (Dimensions.y - ViewBox.Height * Scale) * Align.y),
            Target);
  end;
  Target := AffineTransformation(AffineTranslation(-ViewBox.Left, -ViewBox.Top), Target);
end;

procedure TSVGImage.ReadAspectRatio(out Align: TRealPoint; out Meet: Boolean);
var
  Splitter: TStyleSplitter;
begin
  Align := RealPoint(0.5, 0.5); // Align gibt die Position im Rechteck in Anteilen an (oder x=-1 bei none)
  Meet := True;
  Splitter := TStyleSplitter.Create(XML.GetAttribute('preserveAspectRatio'), True);
  try
    if Length(Splitter.Values) >= 1 then
    begin
      if Splitter.Values[0] = 'none' then Align := RealPoint(-1,0) else
      if Splitter.Values[0] = 'xMinYMin' then Align := RealPoint(0, 0) else
      if Splitter.Values[0] = 'xMidYMin' then Align := RealPoint(0.5, 0) else
      if Splitter.Values[0] = 'xMaxYMin' then Align := RealPoint(1, 0) else
      if Splitter.Values[0] = 'xMinYMid' then Align := RealPoint(0, 0.5) else
      if Splitter.Values[0] = 'xMaxYMid' then Align := RealPoint(1, 0.5) else
      if Splitter.Values[0] = 'xMinYMax' then Align := RealPoint(0, 1) else
      if Splitter.Values[0] = 'xMidYMax' then Align := RealPoint(0.5, 1) else
      if Splitter.Values[0] = 'xMaxYMax' then Align := RealPoint(0, 1);
      if Length(Splitter.Values) >= 2 then
      Meet := Splitter.Values[1] <> 'slice';
    end;
  finally
    Splitter.Free;
  end;
end;

procedure TSVGImage.ReadDimensions(var Dimensions: TRealPoint; const Context: TSVGContext);
begin
  Dimensions.x := GetOnlyValueDef('width', Context.LastViewBox.Width, Context.LastViewBox.Width);
  Dimensions.y := GetOnlyValueDef('height', Context.LastViewBox.Height, Context.LastViewBox.Height);
end;

procedure TSVGImage.ReadFill(var Fill: TFill);
var
  s: string;
  f: Extended;
  TempColor: TColor;
begin
  // F�llung
  if GetProperty('fill',True,True,s) then
  begin
    if (s = 'none') or (s = 'transparent') then
    Fill.Color := clNone
    else
    if GetColorExt(s, TempColor) then
    Fill.Color := TempColor;
  end;

  // Deckf�higkeit (wird entweder als transparent oder nicht interpretiert)
  if GetProperty('fill-opacity', True, True, s) then
  if TCoordinates.GetOnlyValue(s, f) then
  Fill.Opacity := f;

  // Umgang mit �berschneidungen
  if GetProperty('fill-rule',True,True,s) then
  if s = 'nonzero' then
  Fill.Rule := WINDING
  else
  if s = 'evenodd' then
  Fill.Rule := ALTERNATE;
end;

procedure TSVGImage.ReadFont(var Font: TCSSFont);
var
  s: string;
  temp: Extended;
  fonts: TStyleSplitter;
  success: Boolean;
procedure SetFont(const Name: string);
begin
  Font.Family := Name;
  success := True;
end;
begin
  // Schriftfarbe
  if GetProperty('font-family', True, True, s) then
  begin
    success := False;
    fonts := TStyleSplitter.Create(s, False);
    for s in fonts.Values do
    begin
      if SameText(s, 'sans-serif') then // case-insensitive
      SetFont('Arial')
      else
      if SameText(s, 'serif') then
      SetFont('Times New Roman')
      else
      if SameText(s, 'fantasy') then
      SetFont('Comic Sans MS')
      else
      if SameText(s, 'cursive') then
      SetFont('Mistral')
      else
      if SameText(s, 'monospace') then
      SetFont('Courier New')
      else
      begin
        if Screen.Fonts.IndexOf(s) > -1 then // standardm��ig case-insensitive, hier auch richtig
        SetFont(s);
      end;
      if Success then Break;
    end;
    fonts.Free;
  end;

  // Schriftgr��e, % bezieht sich auf die vorherige Einstellung
  if GetProperty('font-size', True, True, s) then
  if TCoordinates.GetOnlyValue(s, temp)  then
  if temp < 0 then
  Font.Size := Font.Size*temp
  else
  Font.Size := temp;

  if GetProperty('font-style', True, True, s) then
  if (s = 'oblique') or (s = 'italic') then
  Font.Style := True
  else
  if (s = 'normal') then
  Font.Style := False;

  if GetProperty('font-weight', True, True, s) then
  if (s = 'bolder') or (s = 'bold') or (s = '600') or (s = '700') or (s = '800') or (s = '900') then
  Font.Weight := True
  else
  if (s = 'normal') or (s = 'lighter') or (s = 'light') or (s = '100') or (s = '200') or (s = '300') or (s = '400') or (s = '500') then
  Font.Weight := False;
end;

function TSVGImage.ReadPosition: TRealPoint;
begin
  Result.x := GetOnlyValueDef('x', 0);
  Result.y := GetOnlyValueDef('y', 0);
end;

procedure TSVGImage.ReadStroke(var Stroke: TStroke);
var
  s: string;
  f: Extended;
  TempColor: TColor;
begin
  // Farbe
  if GetProperty('stroke',True,True,s) then
  if (s = 'none') or (s = 'transparent') then
  Stroke.Color := clNone
  else
  if GetColorExt(s, TempColor) then
  Stroke.Color := TempColor;

  // Deckf�higkeit (wird entweder als transparent oder nicht interpretiert)
  if GetProperty('stroke-opacity', True, True, s) then
  if TCoordinates.GetOnlyValue(s, f) then
  Stroke.Opacity := f;

  // Gehrungsgrenze
  if GetProperty('stroke-miterlimit', True, True, s) then
  if TCoordinates.GetOnlyValue(s, f) then
  Stroke.Miterlimit := f;

  // Breite
  if GetProperty('stroke-width',True,True,s) then
  if s = 'none' then // stroke-width: none; hat keinen Einfluss auf stroke-width
  Stroke.Color := clNone
  else
  Stroke.Width := TCoordinates.GetOnlyValueDef(s, -1, Stroke.Width);

  // Enden
  if GetProperty('stroke-linecap',True,True,s) then
  if SameText(s, 'butt') then
  Stroke.Linecap := PS_ENDCAP_FLAT
  else
  if SameText(s, 'round')  then
  Stroke.Linecap := PS_ENDCAP_ROUND
  else
  if SameText(s, 'square') then
  Stroke.Linecap := PS_ENDCAP_SQUARE;

  // Ecken
  if GetProperty('stroke-linejoin',True,True,s) then
  if SameText(s, 'miter') then
  Stroke.Linejoin := PS_JOIN_MITER
  else
  if SameText(s, 'round')  then
  Stroke.Linejoin := PS_JOIN_ROUND
  else
  if SameText(s, 'bevel') then
  Stroke.Linejoin := PS_JOIN_BEVEL;

  // Strichelungen (k�nnen prozentual sein und werden deshalb sp�ter erst interpretiert)
  if GetProperty('stroke-dasharray',True,True,s) then
  Stroke.Dasharray := s;
end;

function TSVGImage.ReadStyle(var Context: TSVGContext): Boolean;
var
  s, Name, Content: string;
  steps: TStyleSplitter;
  params: TCoordinates;
  x1, x2, x3, x4, x5, x6: Extended;
  i: Integer;
begin
  Result := False;

  //if XML.CurrentTag = 'g' then
  {if XML.GetAttribute('id', s) then
  if not Symbols.ContainsKey(s) then
  Symbols.Add(s, XML.Position);}

  // Sichtbarkeit laden, ggf. abbrechen, da display auch das Zeichnen aller Kinder verhindert
  if not Context.Display then Exit;
  CurrentStyle := TStyle.Create(XML.GetAttributeDef('style', ''));
  try
    if GetProperty('display', True, True, s) then
    Context.Display := Context.Display and (s <> 'none');
    if not Context.Display then Exit;

    // Deckf�higkeit (wird entweder als transparent oder nicht interpretiert)
    if GetProperty('opacity', True, True, s) then
    if TCoordinates.GetOnlyValue(s, x1) then
    Context.Opacity := Context.Opacity * x1; // berechnet sich anders als F�llungs- und Konturendeckkraft relativ
    Context.Display := not (Context.Opacity < 0.2);
    if not Context.Display then Exit;

    // Zeichenreihenfolge laden
    if GetProperty('paint-order', True, True, s) then
    Context.PaintOrderStroke := s = 'stroke';

    // F�llungs-, Konturen- und Schrifteigenschaften laden
    ReadFill(Context.Fill);
    ReadStroke(Context.Stroke);
    ReadFont(Context.Font);

    // Affine Abbildungen laden
    if XML.GetAttribute('transform', s) then // keine CSS-Eigenschaft!
    try
      steps := TStyleSplitter.Create(s, True);
      try
        for i := Low(Steps.Values) to High(Steps.Values) do // es werden immer neue innere (d.h. als erstes (direkt nach R�ckg�ngigmachung von TempScale) auszuf�hrende!) Transformationen angeh�ngt
        begin
          TStyleSplitter.GetBracket(Steps.Values[i], Name, Content);
          params := TCoordinates.Create(Content);
          try
            // Translation, Name ist �brigens case-sensitive
            if Name = 'translate' then
            begin
              if params.GetNextCoordinate(x1) and params.GetNextCoordinate(x2) then
              Context.Transformations := AffineTransformation(AffineTranslation(x1, x2), Context.Transformations);
            end else
            // Drehung
            if Name = 'rotate' then
            begin
              if params.GetNextCoordinate(x1) then
              if params.GetNextCoordinate(x2) and params.GetNextCoordinate(x3) then
              Context.Transformations := AffineTransformation(AffineRotation(x1, x2, x3), Context.Transformations)
              else
              Context.Transformations := AffineTransformation(AffineRotation(x1), Context.Transformations);
            end else
            // Streckung und Stauchung
            if Name = 'scale' then
            begin
              if params.GetNextCoordinate(x1) then
              if params.GetNextCoordinate(x2) then
              Context.Transformations := AffineTransformation(AffineScale(x1, x2), Context.Transformations)
              else
              Context.Transformations := AffineTransformation(AffineScale(x1, x1), Context.Transformations);
            end else
            // 2 verschiedene Scherungen
            if Name = 'skewX' then
            begin
              if params.GetNextCoordinate(x1) then
              Context.Transformations := AffineTransformation(AffineSkewX(x1), Context.Transformations);
            end else
            if Name = 'skewY' then
            begin
              if params.GetNextCoordinate(x1) then
              Context.Transformations := AffineTransformation(AffineSkewY(x1), Context.Transformations);
            end else
            // Affine Abbildung
            if Name = 'matrix' then
            begin
              if params.GetNextCoordinate(x1) and params.GetNextCoordinate(x2) and params.GetNextCoordinate(x3) and
                 params.GetNextCoordinate(x4) and params.GetNextCoordinate(x5) and params.GetNextCoordinate(x6) then
              Context.Transformations := AffineTransformation(AffineTransformation(x1,x2,x3,x4,x5,x6), Context.Transformations);
            end;
          finally
            params.Free;
          end;
        end;
      finally
        steps.Free;
      end;
    except
    end;

    Result := True;
  finally
    CurrentStyle.Free;
  end;
end;

function TSVGImage.ReadViewbox(var ViewBox: TRealRect): Boolean;
var
  Coords: TCoordinates;
  Value: string;
  TempViewbox: TRealRect;
begin
  Result := XML.GetAttribute('viewbox', Value);
  if Result then
  begin
    Coords := TCoordinates.Create(Value);
    try
      Result := Coords.GetNextCoordinate(TempViewbox.Left) and
                Coords.GetNextCoordinate(TempViewbox.Top) and
                Coords.GetNextCoordinate(TempViewbox.Width) and
                Coords.GetNextCoordinate(TempViewbox.Height);
      if Result then
      ViewBox := TempViewbox; // nur setzen, wenn vollst�ndig geladen
    finally
      Coords.Free;
    end;
  end;
end;

{ TCustomUTF8Encoding }

constructor TCustomUTF8Encoding.Create;
begin
  inherited Create(CP_UTF8, 0, 0); // TEncoding.UTF8 ohne MB_ERR_INVALID_CHARS
end;

initialization
  TPicture.RegisterFileFormat('SVG', 'Scalable Vector Graphics', TSVGImage);
finalization
  TPicture.UnregisterGraphicClass(TSVGImage);

end.
