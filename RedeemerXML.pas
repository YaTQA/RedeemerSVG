unit RedeemerXML;

interface

uses Generics.Collections;

type TRedeemerXML = class
  public
    constructor Create(const Text: string);
    destructor Destroy(); override;
    class function Clean(const Text: string): string;
    function  GoToAndGetNextTag: Boolean;
    function  IsSelfClosing(): Boolean;
    procedure LoadAttributes;
    procedure LoadTagName;
    function  GetAttribute(const Attribute: string): string; overload;
    function  GetAttribute(const Attribute: string; var Value: string): Boolean; overload;
    function  GetAttributeDef(const Attribute: string; const Def: string): string; overload;
    function  GetInnerTextAndSkip: string;
    var
      CurrentTag: string;
      Position: Integer;
      Done: Boolean;
      Attributes: TDictionary<string,string>;
    Text: string;
  end;

implementation

uses
  SysUtils, StrUtils, Math, RedeemerEntities, DateUtils;

{ TRedeemerXML }

constructor TRedeemerXML.Create(const Text: string);
begin
  Self.Text := Clean(Text) + ' ';
  Position := 0;
  Done := False;
  Attributes := Generics.Collections.TDictionary<string,string>.Create();
end;

destructor TRedeemerXML.Destroy;
begin
  Attributes.Free;
  inherited;
end;

class function TRedeemerXML.Clean(const Text: string): string;
var
  i,j: Integer;
  CanISpace: Boolean;
begin
  CanISpace := False; // Only Poland Can Into Space!
  Result := Text; // Speicher reservieren
  j := 1;
  for i := 1 to Length(Text) do
  case Ord(Text[i]) of
    9, 10, 13, 32: if CanISpace then
                   begin
                     Result[j] := #32;
                     CanISpace := False;
                     inc(j);
                   end;
    else begin
           Result[j] := Text[i];
           CanISpace := True;
           inc(j);
         end;
  end;
  Result := Copy(Result, 1, j-1);
end;

function TRedeemerXML.GetAttribute(const Attribute: string): string;
begin
  Result := '';
  GetAttribute(Attribute, Result);
end;

function TRedeemerXML.GetAttribute(const Attribute: string; var Value: string): Boolean;
begin
  Result := Attributes.ContainsKey(Lowercase(Attribute));
  if Result then
  Value := Attributes[Lowercase(Attribute)];
end;

function TRedeemerXML.GetAttributeDef(const Attribute, Def: string): string;
begin
  Result := Def;
  GetAttribute(Attribute, Result);
end;

function TRedeemerXML.GetInnerTextAndSkip: string;
var
  EndTag: string;
  i: Integer;
begin
  Result := '';
  if IsSelfClosing then Exit; // Inhaltslos
  EndTag := '/' + CurrentTag;
  repeat
    i := PosEx('>', Text, Position) + 1;
    if not GoToAndGetNextTag then Break;
    Result := Result + RemoveEntities(Copy(Text, i, Position - i));
  until EndTag = CurrentTag;
  Result := Clean(Result);
end;

function TRedeemerXML.GoToAndGetNextTag: Boolean;
var
  i: Integer;
begin
  Result := False;
  Position := PosEx('<', Text, Position + 1);
  if (Position = 0) or Done then
  begin
    Done := True;
    Exit;
  end;
  // Kommentar
  if Copy(Text, Position+1, 3) = '!--' then
  begin
    i := PosEx('-->', Text, Position);
    if i > 0 then
    begin
      Position := i;
      Result := GoToAndGetNextTag;
      //Position := i;
    end;
    Exit;
  end;
  // Kein Kommentar
  LoadTagName();
  LoadAttributes();
  Result := True;
end;

function TRedeemerXML.IsSelfClosing: Boolean;
begin
  Result := Attributes.ContainsKey('/'); // Dieser Lösungsansatz ist so unglaublich banal
end;

procedure TRedeemerXML.LoadAttributes;
var
  i, j, l: Integer;
  temp: string;
  Value: string;
function MinNotZero(const Char1: string): Integer;
var
  x1, x2: Integer;
begin
  x1 := PosEx('>', Text, i+1);
  x2 := PosEx(Char1, Text, i+1);
  if x1 = 0 then
  Result := x2
  else
  if x2 = 0 then
  Result := x1
  else
  Result := Min(x1, x2);
end;
begin
  Attributes.Clear;
  i := Position;
  l := Length(Text);
  Temp := '';
  while i <= l do
  if Text[i] = '>' then
  begin
    if Temp <> '' then
    if not Attributes.ContainsKey(Temp) then // kein Überbleibsel
    Attributes.Add(Temp, ''); // Leeres Attribut
    Exit;
  end
  else
  if Text[i] = '=' then
  begin
    if Text[i+1] = '"' then
    begin
      j := PosEx('"', Text, i+2);
      Value := RemoveEntities(Copy(Text, i+2, j - i - 2));
      Attributes.Add(temp, value);
      inc(j, 1);
    end
    else
    if Text[i+1] = '''' then
    begin
      j := PosEx('''', Text, i+2);
      Value := RemoveEntities(Copy(Text, i+2, j - i - 2));
      Attributes.Add(temp, value);
      inc(j, 1);
    end
    else
    begin
      j := MinNotZero(' ');
      Value := RemoveEntities(Copy(Text, i+1, j - i - 1));
      Attributes.Add(temp, value);
    end;
    i := j;
  end
  else
  if Text[i] = ' ' then
  begin
    j := MinNotZero('=');
    Temp := lowercase(Copy(Text, i+1, j - i - 1));
    i := j;
  end
  else
  inc(i);
end;

procedure TRedeemerXML.LoadTagName;
var
  i: Integer;
begin
  i := Min(PosEx('>', Text, Position+1), PosEx(' ', Text, Position+1));
  CurrentTag := lowercase(Copy(Text, Position+1, i - Position - 1));
end;

end.
