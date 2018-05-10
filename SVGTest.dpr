program SVGTest;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  RedeemerHypertextColors in 'RedeemerHypertextColors.pas',
  RedeemerSVG in 'RedeemerSVG.pas',
  RedeemerAffineGeometry in 'RedeemerAffineGeometry.pas',
  Kollegah in 'Kollegah.pas',
  RedeemerXML in 'RedeemerXML.pas',
  RedeemerEntities in 'RedeemerEntities.pas',
  RedeemerHypertextColorsCSS in 'RedeemerHypertextColorsCSS.pas',
  RedeemerHypertextColorsX11 in 'RedeemerHypertextColorsX11.pas',
  RedeemerFloat in 'RedeemerFloat.pas',
  RedeemerScale in 'RedeemerScale.pas',
  RedeemerSVGHelpers in 'RedeemerSVGHelpers.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
