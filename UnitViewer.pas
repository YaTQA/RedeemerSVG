unit UnitViewer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Menus, RedeemerSVG;

type
  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    MenuOpen: TMenuItem;
    MenuSave: TMenuItem;
    Image1: TImage;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    procedure MenuOpenClick(Sender: TObject);
    procedure MenuSaveClick(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

uses DateUtils;

{$R *.dfm}

procedure TForm1.MenuOpenClick(Sender: TObject);
var
  SVG: TSVGImage;
  TimeStamp: TDateTime;
begin
  if OpenDialog1.Execute then
  begin
    SVG := TSVGImage.Create;
    try
      TimeStamp := Now;
      SVG.LoadFromFile(OpenDialog1.FileName);
      Caption := 'Geladen in: ' + IntToStr(MilliSecondsBetween(Now, Timestamp)) + ' ms';
      MenuSave.Enabled := True;
      Image1.Picture.Assign(SVG);
    finally
      SVG.Free;
    end;
  end;
end;

procedure TForm1.MenuSaveClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
  Image1.Picture.Graphic.SaveToFile(SaveDialog1.FileName);
end;

end.
