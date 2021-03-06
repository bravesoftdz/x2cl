unit FMainGL;

interface
uses
  Classes,
  ComCtrls,
  Controls,
  ExtCtrls,
  Forms,
  ImgList,
  Menus,
  PNGImage,
  ToolWin,
  X2CLGraphicList;

type
  TfrmMain = class(TForm)
    gcMain:                       TX2GraphicContainer;
    glMain:                       TX2GraphicList;
    glMainDisabled:               TX2GraphicList;
    glTree:                       TX2GraphicList;
    mnuMain:                      TMainMenu;
    mnuTest:                      TMenuItem;
    mnuTestImage:                 TMenuItem;
    tbMain:                       TToolBar;
    tbTest:                       TToolButton;
    tvTest:                       TTreeView;
  end;

implementation

{$R *.dfm}

end.
