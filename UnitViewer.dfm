object Form1: TForm1
  Left = 0
  Top = 0
  Width = 651
  Height = 358
  AutoScroll = True
  Caption = 'TRedeemerSVG-Demo'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poDefault
  Scaled = False
  PixelsPerInch = 96
  TextHeight = 13
  object Image1: TImage
    Left = 0
    Top = 0
    Width = 105
    Height = 105
    AutoSize = True
  end
  object MainMenu1: TMainMenu
    Left = 312
    Top = 152
    object MenuOpen: TMenuItem
      Caption = 'SVG '#246'ffnen'
      OnClick = MenuOpenClick
    end
    object MenuSave: TMenuItem
      Caption = 'PNG speichern'
      Enabled = False
      OnClick = MenuSaveClick
    end
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = 'svg'
    Filter = 'Scalable Vector Graphic (*.svg)|*.svg'
    Left = 160
    Top = 40
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'png'
    Filter = 'Portable Network Graphic (*.png)|*.png'
    Left = 248
    Top = 40
  end
end
