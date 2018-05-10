unit RedeemerSVG;

(* RedeemerSVG.TSVGImage
 * 0.2b-alpha
 * Copyright © 2017 Janni K. (redeemer.biz)
 *
 * Aufgrund des frühen Entwicklungsstadiums:
 * Lizenziert unter der Microsoft Reference Source License
 * Weiterverbreitung des Quelltextes und abgeleiteter Werke nur mit Erlaubnis
 *)

interface

uses
  PNGImage, Graphics, Sysutils, RedeemerAffineGeometry, RedeemerXML, Windows,
  RedeemerHypertextColors, RedeemerHypertextColorsCSS, Classes, RedeemerFloat,
  StrUtils, Kollegah, Math, RedeemerScale, RedeemerSVGHelpers, inifiles, Types,
  Generics.Collections;

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
  Rule: Integer; // ALTERNATE, WINDING
end;

type TStroke = record
  Width: Extended; // negative Angaben: Prozent, bedeutet Prozent/100*sqrt((Breite²+Höhe²)/2)
  Linecap: Cardinal;
  Linejoin: Cardinal;
  //Miterlimit: Single;
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
  Transformations: TAffineTransformation;
  LastViewport: TRealRect;
  Dimensions: TRealPoint;
  Fill: TFill;
  Stroke: TStroke;
  Font: TCSSFont;
  Display: Boolean;
  PaintOrderStroke: Boolean;
end;

type TSizeCallbackEvent = procedure (const Viewport: TRealRect; var Dimensions: TRealPoint) of object;

type TSVGImage = class(TPNGImage)
  private
    procedure InitDrawing();
    procedure FinishDrawing(const Context: TSVGContext);
    function  GetProperty(const Name: string; const CanAttribute: Boolean; const CanCSS: Boolean; out Value: string): Boolean;
    function GetOnlyValue(const Attribute: string; out Value: Extended): Boolean; overload;
    function GetOnlyValue(const Attribute: string; out Value: Extended; const PercentageMeasure: Extended): Boolean; overload;
    function GetOnlyValueDef(const Attribute: string; const Default: Extended): Extended; overload;
    function GetOnlyValueDef(const Attribute: string; const PercentageMeasure: Extended; const Default: Extended): Extended; overload;
    function GetURLRef(const URL: string; const List: TDictionary<string,Integer>; out Value: Integer): Boolean;
    function GetColorExt(const S: string; out Color: TColor): Boolean;
    procedure LoadBrush(const Fill: TFill);
    procedure LoadPen(const Stroke: TStroke; const Context: TSVGContext);
    procedure LoadFont(const Font: TCSSFont);
    procedure DrawPoly(Context: TSVGContext; const d: string);
    procedure HandleGroup(Context: TSVGContext); // svg, g
    procedure HandleCircle(Context: TSVGContext; const IsEllipse: Boolean);
    procedure HandleRect(Context: TSVGContext);
    procedure HandleLine(Context: TSVGContext);
    procedure HandleText(Context: TSVGContext);
    procedure HandleUse(Context: TSVGContext);
    procedure HandleDefs();
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
    constructor Create(); reintroduce;
    procedure LoadFromStream(Stream: TStream); override;
end;

function RealRect(Left, Top, Width, Height: Extended): TRealRect;

var
  SizeCallback: TSizeCallbackEvent = nil;

implementation

uses
  Forms, DateUtils; // für Screen

function RealRect(Left, Top, Width, Height: Extended): TRealRect;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Width := Width;
  Result.Height := Height;
end;

{ TSVGImage }

constructor TSVGImage.Create;
begin
  inherited CreateBlank(COLOR_RGBALPHA, 8, 1, 1); // 0 führt beim Setzen einer neuen Größe zum Fehler
end;

procedure TSVGImage.DrawPoly(Context: TSVGContext; const d: string);
var
  p: TPath;
  LastEndpoint, LastBezier, NextEndpoint, FirstBezier, SecondBezier: TRealPoint;
  Dummy: Extended;
function ConditionalRelativeX(var f: Extended): Extended;
begin
  if AnsiChar(p.LastType) in ['a'..'z'] then
  Result := LastEndpoint.x + f
  else
  Result := f;
end;
function ConditionalRelativeY(var f: Extended): Extended;
begin
  if AnsiChar(p.LastType) in ['a'..'z'] then
  Result := LastEndpoint.y + f
  else
  Result := f;
end;
procedure DrawBezier(const P1, P2, P3: TRealPoint);
var
  Points: array[0..2] of tagPOINT;
begin
  Points[0].X := Round(P1.x * TempSupersample);
  Points[0].Y := Round(P1.y * TempSupersample);
  Points[1].X := Round(P2.x * TempSupersample);
  Points[1].Y := Round(P2.y * TempSupersample);
  Points[2].X := Round(P3.x * TempSupersample);
  Points[2].Y := Round(P3.y * TempSupersample);
  PolyBezierTo(ChromaPNG.Canvas.Handle, Points, 3);
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
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               LineTo(ChromaPNG.Canvas.Handle,
                 Round(LastEndpoint.x*TempSupersample),
                 Round(LastEndpoint.y*TempSupersample));
             end;
        // MoveTo
        'M': begin
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               MoveToEx(ChromaPNG.Canvas.Handle,
                 Round(LastEndpoint.x*TempSupersample),
                 Round(LastEndpoint.y*TempSupersample),
                 nil);
             end;
        // Horizontal Line To
        'H': begin
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               LineTo(ChromaPNG.Canvas.Handle,
                 Round(LastEndpoint.x*TempSupersample),
                 Round(LastEndpoint.y*TempSupersample));
             end;
        // Vertical Line To
        'V': begin
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               LineTo(ChromaPNG.Canvas.Handle,
                 Round(LastEndpoint.x*TempSupersample),
                 Round(LastEndpoint.y*TempSupersample));
             end;
        // ClosePath
        'Z': CloseFigure(ChromaPNG.Canvas.Handle);
        // CubicBézierCurveTo
        'C', 'S': begin
               if UpperCase(p.LastType) = 'S' then
               begin
                 // Punktspiegelung
                 FirstBezier.x := 2 * LastEndpoint.x - LastBezier.x;
                 FirstBezier.y := 2 * LastEndpoint.y - LastBezier.y;
               end
               else
               begin
                 if not p.GetNextNumber(FirstBezier.x) then Abort;
                 if not p.GetNextNumber(FirstBezier.y) then Abort;
                 FirstBezier.x := ConditionalRelativeX(FirstBezier.x);
                 FirstBezier.y := ConditionalRelativeY(FirstBezier.y);
               end;
               if not p.GetNextNumber(LastBezier.x) then Abort;
               if not p.GetNextNumber(LastBezier.y) then Abort;
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               LastBezier.x := ConditionalRelativeX(LastBezier.x);
               LastBezier.y := ConditionalRelativeY(LastBezier.y);
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               DrawBezier(FirstBezier, LastBezier, LastEndpoint);
             end;
        // QuadraticBézierCurveTo
        'Q', 'T': begin
               if UpperCase(p.LastType) = 'T' then
               begin
                 // Punktspiegelung
                 LastBezier.x := 2 * LastEndpoint.x - LastBezier.x;
                 LastBezier.y := 2 * LastEndpoint.y - LastBezier.y;
               end
               else
               begin
                 if not p.GetNextNumber(FirstBezier.x) then Abort;
                 if not p.GetNextNumber(FirstBezier.y) then Abort;
                 LastBezier.x := ConditionalRelativeX(FirstBezier.x);
                 LastBezier.y := ConditionalRelativeY(FirstBezier.y);
               end;
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               // Umwandeln von quadratischer Kurve in kubische Kurve (laut deutscher Wikipedia)
               FirstBezier.x := LastEndpoint.x + 2 * (LastBezier.x - LastEndpoint.x) / 3;
               FirstBezier.y := LastEndpoint.y + 2 * (LastBezier.y - LastEndpoint.y) / 3;
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               SecondBezier.x := LastEndpoint.x + 2 * (LastBezier.x - LastEndpoint.x) / 3;
               SecondBezier.y := LastEndpoint.y + 2 * (LastBezier.y - LastEndpoint.y) / 3;
               DrawBezier(FirstBezier, SecondBezier, LastEndpoint);
             end;
        // ArcTo (wird zu einer Geraden)
        'A': begin
               if not p.GetNextNumber(Dummy) then Abort;
               if not p.GetNextNumber(Dummy) then Abort;
               if not p.GetNextNumber(Dummy) then Abort;
               if not p.GetNextNumber(Dummy) then Abort;
               if not p.GetNextNumber(Dummy) then Abort;
               if not p.GetNextNumber(NextEndpoint.x) then Abort;
               if not p.GetNextNumber(NextEndpoint.y) then Abort;
               LastEndpoint.x := ConditionalRelativeX(NextEndpoint.x);
               LastEndpoint.y := ConditionalRelativeY(NextEndpoint.y);
               LineTo(ChromaPNG.Canvas.Handle,
                 Round(LastEndpoint.x*TempSupersample),
                 Round(LastEndpoint.y*TempSupersample));
             end;
        // CentripetalCatmullRomTo (führt zu Abbruch)
        'R': Abort;
        // Bearing (wird ignoriert)
        'B': if not p.GetNextNumber(Dummy) then Abort;
      end;
      FinishDrawing(Context);
    except
      raise Exception.Create('DEBUG: <path> failed at ' + IntToStr(p.Position) + ' on input:' + #13#10 + d);
      AbortPath(ChromaPNG.Canvas.Handle);
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
    if not GetOnlyValue('rx',rx,Context.LastViewport.Width) then Exit;
    if not GetOnlyValue('ry',ry,Context.LastViewport.Height) then Exit;
  end
  else
  begin
    if not GetOnlyValue('r',rx,(sqrt((sqr(Context.LastViewport.Width) + sqr(Context.LastViewport.Height)) / 2))) then Exit;
    ry := rx;
  end;

  begin
    InitDrawing;
    cx := GetOnlyValueDef('cx',Context.LastViewport.Width,0);
    cy := GetOnlyValueDef('cy',Context.LastViewport.Height,0);
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
  NextStopName := '';
  while XML.GoToAndGetNextTag do
  begin
    // Gruppen müssen bearbeitet werden, damit die Sichtbarkeit korrekt für alle Unterelement gilt, Rest nicht
    if SameText(XML.CurrentTag, '/defs') then
    Exit
    else
    if SameText(XML.CurrentTag, 'symbol') then
    Symbols.Add(XML.GetAttributeDef('id', ''), XML.Position)
    else
    if SameText(XML.CurrentTag, 'radialGradient') or SameText(XML.CurrentTag, 'linearGradient') then
    NextStopName := XML.GetAttributeDef('id', '')
    else
    if SameText(XML.CurrentTag, 'stop') and (NextStopName <> '') then
    if RedeemerHypertextColors.HTMLToColor(XML.GetAttributeDef('stop-color', ''), i, CSSColors) then
    begin
      Colors.Add(NextStopName, Integer(i));
      NextStopName := '';
    end
    else
    else
    if SameText(XML.CurrentTag, 'solidcolor') then
    if RedeemerHypertextColors.HTMLToColor(XML.GetAttributeDef('solid-color', ''), i, CSSColors) then
    begin
      Colors.Add(XML.GetAttributeDef('id', ''), Integer(i));
      NextStopName := '';
    end;
  end;
end;

procedure TSVGImage.HandleGroup(Context: TSVGContext);
var
  d, CancelTag: string;
  Draw: Boolean;
begin
  Draw := ReadStyle(Context);
  CancelTag := '/' + XML.CurrentTag;
  while XML.GoToAndGetNextTag do
  begin
    // Gruppen müssen bearbeitet werden, damit die Sichtbarkeit korrekt für alle Unterelement gilt, Rest nicht
    if XML.CurrentTag = CancelTag then
    Exit
    else
    if XML.CurrentTag = 'g' then
    HandleGroup(Context)
    else
    if XML.CurrentTag = 'defs' then
    HandleDefs()
    else
    // falls gezeichnet werden muss, bearbeite sichtbare Objekte
    if Draw then
    if XML.CurrentTag = 'use' then
    HandleUse(Context)
    else
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
      if XML.GetAttribute(string('d'), d) then // Ob er behindert ist, hab ich gefragt!?
      DrawPoly(Context, d);
    end
    else
    if XML.CurrentTag = 'text' then
    HandleText(Context);
  end;
end;

procedure TSVGImage.HandleLine(Context: TSVGContext);
begin
  if not ReadStyle(Context) then Exit;
  InitDrawing;
  MoveToEx(ChromaPNG.Canvas.Handle,
    Round(GetOnlyValueDef('x1',Context.LastViewport.Width,0)*TempSupersample),
    Round(GetOnlyValueDef('y1',Context.LastViewport.Height,0)*TempSupersample),
    nil);
  LineTo(ChromaPNG.Canvas.Handle,
    Round(GetOnlyValueDef('x2',Context.LastViewport.Width,0)*TempSupersample),
    Round(GetOnlyValueDef('y2',Context.LastViewport.Height,0)*TempSupersample));
  FinishDrawing(Context);
end;

procedure TSVGImage.HandleRect(Context: TSVGContext);
var
  x,y,h,w: Extended;
begin
  if not ReadStyle(Context) then Exit;
  if GetOnlyValue('width',w,Context.LastViewport.Width) then
  if GetOnlyValue('height',h,Context.LastViewport.Height) then
  begin
    InitDrawing;
    x := GetOnlyValueDef('x',Context.LastViewport.Width,0);
    y := GetOnlyValueDef('y',Context.LastViewport.Height,0);
    RoundRect(ChromaPNG.Canvas.Handle,
      Integer(Round(x*TempSupersample)),
      Integer(Round(y*TempSupersample)),
      Integer(Round((x+w)*TempSupersample)),
      Integer(Round((y+h)*TempSupersample)),
      Integer(Round(GetOnlyValueDef('rx',Context.LastViewport.Width,0)*2*TempSupersample)),
      Integer(Round(GetOnlyValueDef('ry',Context.LastViewport.Height,0)*2*TempSupersample))
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
  SetTextAlign(ChromaPNG.Canvas.Handle, TA_LEFT or TA_BASELINE);
  if XML.GetAttribute('text-anchor', s) then
  if s = 'end' then
  SetTextAlign(ChromaPNG.Canvas.Handle, TA_RIGHT or TA_BOTTOM)
  else
  if s = 'middle' then
  SetTextAlign(ChromaPNG.Canvas.Handle, TA_CENTER or TA_BOTTOM);
  // Text zeichnen
  s := XML.GetInnerTextAndSkip;
  if s <> '' then
  begin
    InitDrawing();
    LoadFont(Context.Font);

    // Zählen, in wievielen Einzelteilen der Text gerendet werden muss
    count := 0;
    while x.GetNextCoordinate(1, x2) do // konkreter Wert für Prozentwert derzeit egal
    inc(count);
    x.Position := 1; // Position des Koordinaten-Splitters fürs tatsächliche Rendern zurücksetzen

    // Einzelteile rendern
    i := 0;
    while x.GetNextCoordinate(Context.LastViewport.Width, x2) do
    begin
      inc(i);
      if i < count then
      begin
      s2 := LeftStr(s, 1);
      Delete(s, 1, 1);
      end
      else
      s2 := s;
      y.GetNextCoordinate(Context.LastViewport.Height, y2); // wenn nicht, dann halt nicht (bleibt unverändert)
      ExtTextOut(ChromaPNG.Canvas.Handle, Integer(Round(x2*TempSupersample)), Integer(Round(y2*TempSupersample)), 0, nil, PChar(s2), Length(s2), nil);
    end;
    FinishDrawing(Context);
  end;
end;

procedure TSVGImage.HandleUse(Context: TSVGContext);
var
  OldPos, NewPos: Integer;
  s: string;
begin
  ReadStyle(Context); // Eigenschaften des aufrufenden use-Tags lesen
  OldPos := XML.Position;
  if XML.GetAttribute('xlink:href', s) then
  if GetURLRef(s, Symbols, NewPos) then
  if not Recalls.Contains(s) then
  try
    XML.Position := NewPos;
    NewPos := Recalls.Add(s);
    XML.LoadTagName;
    XML.LoadAttributes;
    HandleGroup(Context);
    Recalls.Delete(NewPos);
  finally
    XML.Position := OldPos;
    //XML.LoadAttributes;
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
  Value: string;
  haswidth, hasheight: Boolean;
  Coords: TCoordinates;
  Scale: Extended;
  Encoding: TCustomUTF8Encoding;
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
      // Erstmal Größe lesen
      hasWidth := GetOnlyValue('width', Context.Dimensions.x);
      if not haswidth then
      Context.Dimensions.x := 300;
      hasHeight := GetOnlyValue('height', Context.Dimensions.y);
      if not hasheight then
      Context.Dimensions.y := 300;

      if XML.GetAttribute('viewbox', Value) then
      begin
        Coords := TCoordinates.Create(Value);
        Coords.GetNextCoordinate(Context.LastViewport.Left);
        Coords.GetNextCoordinate(Context.LastViewport.Top);
        Coords.GetNextCoordinate(Context.LastViewport.Width);
        Coords.GetNextCoordinate(Context.LastViewport.Height);
        if not haswidth then
        Context.Dimensions.x := Context.LastViewport.Width;
        if not hasheight then
        Context.Dimensions.y := Context.LastViewport.Height;
      end
      else
      Context.LastViewport := RealRect(0,0,Context.Dimensions.x,Context.Dimensions.y);

      // Größe vom Benutzer bestätigen lassen
      if Assigned(SizeCallback) then
      SizeCallback(Context.LastViewport, Context.Dimensions);

      // Restlichen Kontext initialisieren
      Context.Fill.Rule := WINDING;
      Context.Fill.Color := clBlack;
      Context.Stroke.Color := clNone;
      Context.Stroke.Width := 1;
      Context.Stroke.Linecap := PS_ENDCAP_FLAT;
      Context.Stroke.Linejoin := PS_JOIN_MITER;
      //Context.Stroke.Miterlimit := 4;
      Context.Font.Family := 'Times New Roman';
      Context.Font.Size := 16;
      Context.Font.Weight := False;
      Context.Font.Style := False;
      Context.Display := True;
      Context.PaintOrderStroke := False;
      // Standard-Bosstransformation
      InnerTransformation := AffineScale(1 / TempSupersample, 1 / TempSupersample);
      Context.Transformations := AffineTransformation(FinalSupersample, 0, 0, FinalSupersample, -0.5 - Context.LastViewport.Left * FinalSupersample, -0.5 - Context.LastViewport.Top * FinalSupersample);

      // Transformation in den richtigen Zeichenbereich
      Scale := Min(Context.Dimensions.x / Context.LastViewport.Width, Context.Dimensions.y / Context.LastViewport.Height);
      Context.Transformations := AffineTransformation(Context.Transformations,
                                 AffineTransformation(Scale, 0, 0, Scale,
                                 (Context.Dimensions.x - Context.LastViewport.Width * Scale) / 2,
                                 (Context.Dimensions.y - Context.LastViewport.Height * Scale) / 2));

      // Zeichenflächen initialisieren (ursprünglicher Join-Algorithmus hatte RGB bei Opacity, war das für Rastergrafiken nötig?)
      ChromaPNG := TPngImage.CreateBlank(COLOR_RGB, 8, Round(Context.Dimensions.x) * FinalSupersample, Round(Context.Dimensions.y) * FinalSupersample);
      OpacityPNG := TPngImage.CreateBlank(COLOR_GRAYSCALE, 8, Round(Context.Dimensions.x) * FinalSupersample, Round(Context.Dimensions.y) * FinalSupersample);

      // Start des Dekodings
      HandleGroup(Context);

      // Zusammenlegen der Bilder
      //inherited CreateBlank(COLOR_RGBALPHA, 8, Round(Context.Dimensions.x), Round(Context.Dimensions.y));
      inherited SetSize(Round(Context.Dimensions.x), Round(Context.Dimensions.y));
      JoinAndDownscale(ChromaPNG, OpacityPNG, self, True);

      Exit; // nur erstes <svg> in der Wurzel bearbeiten (gäbe sonst auch Memory-Leak)
    end;
  finally
    XML.Free;
    Symbols.Free;
    Colors.Free;
  end;
end;

procedure TSVGImage.LoadBrush(const Fill: TFill);
begin
  ChromaPNG.Canvas.Brush.Color := Fill.Color; // wenn man das nach Style setzt, geht das nicht
  if Fill.Color = clNone then
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
  DashData: array of DWord;
  f: Extended;
  PercentageScale: Extended;
  Scale: Extended;
begin
  if (Stroke.Color = clNone) or (Stroke.Width = 0) then
  Flags := PS_NULL // Width kann nicht auf weniger als 1 gesetzt werden, weder mit ExtCreatePen noch mit TPen
  else
  Flags := PS_SOLID;

  PercentageScale := sqrt((sqr(Context.LastViewport.Width) + sqr(Context.LastViewport.Height)) / 2);
  Scale := sqrt((sqr(Context.Transformations.a)+sqr(Context.Transformations.b)+sqr(Context.Transformations.c)+sqr(Context.Transformations.d))/2);

  if Flags <> PS_NULL then
  begin
    Width := Round(TCoordinates.MakeAbsolute(PercentageScale, Stroke.Width)*Scale);
    if Stroke.DashArray <> 'none' then
    begin
      Dashes := TCoordinates.Create(Stroke.DashArray);
      SetLength(DashData, 0);
      try
        while Dashes.GetNextCoordinate(PercentageScale, f) do
        begin
          SetLength(DashData, Length(DashData) + 1);
          DashData[High(DashData)] := Round(f*Scale);
          Flags := PS_USERSTYLE;
          if Length(DashData) = 16 then
          Break; // undokumente Einschränkung von Length(DashData) auf <= 16 in GDI
        end;
        // Deaktivierung eines Sonderfalls in GDI, ein ungerade lange Dasharrays bei ungerade Wiederholungen umkehrt durchläuft
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
  DeleteObject(ChromaPNG.Canvas.Pen.Handle);
  ChromaPNG.Canvas.Pen.Handle := ExtCreatePen(PS_GEOMETRIC or Flags or Stroke.Linecap or Stroke.Linejoin, Width, Brush, Length(DashData), DashData);
  Brush.lbColor := clWhite;
  DeleteObject(OpacityPNG.Canvas.Pen.Handle);
  OpacityPNG.Canvas.Pen.Handle := ExtCreatePen(PS_GEOMETRIC or Flags or Stroke.Linecap or Stroke.Linejoin, Width, Brush, Length(DashData), DashData);
end;

procedure TSVGImage.ReadFill(var Fill: TFill);
var
  s: string;
  TempColor: TColor;
begin
  // Füllung
  if GetProperty('fill',True,True,s) then
  begin
    if (s = 'none') or (s = 'transparent') then
    Fill.Color := clNone
    else
    if GetColorExt(s, TempColor) then
    Fill.Color := TempColor;
  end;

  // Umgang mit Überschneidungen
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
        if Screen.Fonts.IndexOf(s) > -1 then // standardmäßig case-insensitive, hier auch richtig
        SetFont(s);
      end;
      if Success then Break;
    end;

  end;

  // Schriftgröße, % bezieht sich auf die vorherige Einstellung
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

procedure TSVGImage.ReadStroke(var Stroke: TStroke);
var
  s: string;
  TempColor: TColor;
begin
  // Farbe
  if GetProperty('stroke',True,True,s) then
  if (s = 'none') or (s = 'transparent') then
  Stroke.Color := clNone
  else
  if GetColorExt(s, TempColor) then
  Stroke.Color := TempColor;

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

  // Strichelungen (können prozentual sein und werden deshalb später erst interpretiert)
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

  if XML.CurrentTag = 'g' then
  if XML.GetAttribute('id', s) then
  if not Symbols.ContainsKey(s) then
  Symbols.Add(s, XML.Position);

  // Sichtbarkeit laden, ggf. abbrechen, da display auch das Zeichnen aller Kinder verhindert
  if not Context.Display then Exit;
  CurrentStyle := TStyle.Create(XML.GetAttributeDef('style', ''));
  if GetProperty('display', True, True, s) then
  Context.Display := Context.Display and (s <> 'none');
  if not Context.Display then Exit;

  // Zeichenreihenfolge laden
  if GetProperty('paint-order', True, True, s) then
  Context.PaintOrderStroke := s = 'stroke';

  // Füllungs-, Konturen- und Schrifteigenschaften laden
  ReadFill(Context.Fill);
  ReadStroke(Context.Stroke);
  ReadFont(Context.Font);
  
  // Affine Abbildungen laden
  if XML.GetAttribute('transform', s) then // keine CSS-Eigenschaft!
  try
    steps := TStyleSplitter.Create(s, True);
    try
      for i := Low(Steps.Values) to High(Steps.Values) do // es werden immer neue innere (d.h. als erstes (direkt nach Rückgängigmachung von TempScale) auszuführende!) Transformationen angehängt
      begin
        TStyleSplitter.GetBracket(Steps.Values[i], Name, Content);
        params := TCoordinates.Create(Content);
        try
          // Translation, Name ist übrigens case-sensitive
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

end;

{ TCustomUTF8Encoding }

constructor TCustomUTF8Encoding.Create;
begin
  inherited Create(CP_UTF8, 0, 0); // Embas UTF8 setzt MB_ERR_INVALID_CHARS und führt zu dem Problem
end;

initialization
  TPicture.RegisterFileFormat('SVG', 'Scalable Vector Graphics', TSVGImage);
finalization
  TPicture.UnregisterGraphicClass(TSVGImage);

end.
