program GL;

uses
  Forms,
  FMainGL in 'Forms\FMainGL.pas' {frmMain};

{$R *.res}

var
  frmMain:    TfrmMain;

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
