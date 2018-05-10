unit RedeemerXML;

interface

uses Generics.Collections;

type TRedeemerXML = class
  constructor Create(const Text: string);
  //function Fetch(DelimiterChars: string): string;
  private
  public
    class function Clean(const Text: string): string;
    function GoToAndGetNextTag: Boolean;
    procedure LoadAttributes;
    procedure LoadTagName;
    function GetAttribute(const Attribute: string): string; overload;
    function GetAttribute(const Attribute: string; var Value: string): Boolean; overload;
    function GetAttributeDef(const Attribute: string; const Def: string): string; overload;
    function GetInnerTextAndSkip: string;
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
  Value := Attributes[Attribute];
end;

function TRedeemerXML.GetAttributeDef(const Attribute, Def: string): string;
begin
  Result := Def;
  GetAttribute(Attribute, Result);
end;

function TRedeemerXML.GetInnerTextAndSkip: string;
var
  Tag: string;
  i: Integer;
begin
  Result := '';
  Tag := '/' + CurrentTag;
  if PosEx('>', Text, Position) > PosEx('/', Text, Position) then // Inhaltslos
  Exit;
  repeat
    i := PosEx('>', Text, Position) + 1;
    if not GoToAndGetNextTag then Break;
    Result := Result + RemoveEntities(Copy(Text, i, Position - i));
  until Tag = CurrentTag;
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

procedure TRedeemerXML.LoadAttributes;
var
  i, j, l: Integer;
  temp: string;
  Value: string;
begin
  Attributes.Clear;
  i := Position;
  l := Length(Text);
  while i <= l do
  if Text[i] = '>' then
  Exit
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
    if Text[i+1] = '"' then
    begin
      j := PosEx('"', Text, i+2);
      Value := RemoveEntities(Copy(Text, i+2, j - i - 2));
      Attributes.Add(temp, value);
      inc(j, 1);
    end
    else
    begin
      j := Min(PosEx(' ', Text, i+1), PosEx('>', Text, i+1));
      Value := RemoveEntities(Copy(Text, i+1, j - i - 1));
      Attributes.Add(temp, value);
    end;
    i := j;
  end
  else
  if Text[i] = ' ' then
  begin
    j := Min(PosEx('=', Text, i+1), PosEx('>', Text, i+1));
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
