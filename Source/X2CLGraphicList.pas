{
  :: X2CLGraphicList contains a container component for TGraphic
  :: descendants and a replacement for TImageList.
  ::
  :: Many thanks to Erik Stok. While I had the idea to create these components,
  :: he created TPngImageList and worked out many of the problems I thought we
  :: would face. His original (Dutch) article can be found at:
  ::   http://www.erikstok.net/delphi/artikelen/xpicons.html
  ::
  :: Last changed:    $Date$
  :: Revision:        $Rev$
  :: Author:          $Author$
}
unit X2CLGraphicList;

interface
uses
  Windows,

  Classes,
  Controls,
  Graphics;

type
  // Forward declarations
  TX2GraphicList      = class;
  TX2GraphicContainer = class;

  {
    :$ Holds a single graphic.
  }
  TX2GraphicCollectionItem  = class(TCollectionItem, IChangeNotifier)
  private
    FPicture:           TPicture;

    procedure SetPicture(const Value: TPicture);
  protected
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef(): Integer; stdcall;
    function _Release(): Integer; stdcall;

    procedure NotifierChanged();
    procedure IChangeNotifier.Changed = NotifierChanged;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy(); override;
  published
    property Picture:       TPicture  read FPicture write SetPicture;
  end;

  {
    :$ Holds a collection of graphics.
  }
  TX2GraphicCollection      = class(TCollection)
  private
    FContainer:       TX2GraphicContainer;

    function GetItem(Index: Integer): TX2GraphicCollectionItem;
    procedure SetItem(Index: Integer; Value: TX2GraphicCollectionItem);
  protected
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification); override;
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(const AContainer: TX2GraphicContainer);

    function Add(): TX2GraphicCollectionItem;

    property Items[Index: Integer]:   TX2GraphicCollectionItem  read GetItem
                                                                write SetItem; default;
  end;

  {
    :$ Container object for graphics.

    :: TX2GraphicContainer holds all the original graphic data. Link a container
    :: to a TX2GraphicList to provide the graphics for various components.
  }
  TX2GraphicContainer   = class(TComponent)
  private
    FGraphics:        TX2GraphicCollection;

    FLists:           TList;

    procedure SetGraphics(const Value: TX2GraphicCollection);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification); virtual;
    procedure Update(Item: TCollectionItem); virtual;

    procedure RegisterList(const AList: TX2GraphicList);
    procedure UnregisterList(const AList: TX2GraphicList);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
  published
    property Graphics:      TX2GraphicCollection  read FGraphics  write SetGraphics;
  end;

  {
    :$ Defines the various modes for drawing a larger image.
  }
  TX2GLStretchMode  = (smCrop, smStretch);

  {
    :$ ImageList replacement for graphics.
  }
  TX2GraphicList        = class(TImageList)
  private
    FBackground:      TColor;
    FContainer:       TX2GraphicContainer;
    FStretchMode:     TX2GLStretchMode;

    procedure SetBackground(const Value: TColor);
    procedure SetContainer(const Value: TX2GraphicContainer);
    procedure SetStretchMode(const Value: TX2GLStretchMode);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    procedure CreateImage(const AIndex: Integer; var AImage, AMask: TBitmap); virtual;
    procedure AddImage(const AIndex: Integer); virtual;
    procedure UpdateImage(const AIndex: Integer); virtual;
    procedure DeleteImage(const AIndex: Integer); virtual;

    procedure RebuildImages(); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure Loaded(); override;
  published
    property Background:    TColor                read FBackground  write SetBackground   default clBtnFace;
    property Container:     TX2GraphicContainer   read FContainer   write SetContainer;
    property StretchMode:   TX2GLStretchMode      read FStretchMode write SetStretchMode  default smCrop;
  end;

implementation
uses
  Dialogs,
  ImgList,
  SysUtils;

type
  PClass          = ^TClass;

  PRGBTripleArray = ^TRGBTripleArray;
  TRGBTripleArray = array[Word] of TRGBTriple;



{=============== TX2GraphicCollectionItem
  Initialization
========================================}
constructor TX2GraphicCollectionItem.Create;
begin
  inherited;

  FPicture                := TPicture.Create();
  FPicture.PictureAdapter := Self;
end;

destructor TX2GraphicCollectionItem.Destroy;
begin
  FreeAndNil(FPicture);

  inherited;
end;


function TX2GraphicCollectionItem.QueryInterface;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TX2GraphicCollectionItem._AddRef;
begin
  Result  := -1;
end;

function TX2GraphicCollectionItem._Release;
begin
  Result  := -1;
end;


procedure TX2GraphicCollectionItem.NotifierChanged;
begin
  Changed(False);
end;

procedure TX2GraphicCollectionItem.SetPicture;
begin
  FPicture.Assign(Value);
end;


{=================== TX2GraphicCollection
  Item Management
========================================}
constructor TX2GraphicCollection.Create;
begin
  inherited Create(TX2GraphicCollectionItem);

  FContainer  := AContainer;
end;


function TX2GraphicCollection.Add;
begin
  Result  := TX2GraphicCollectionItem(inherited Add());
end;


procedure TX2GraphicCollection.Notify;
begin
  inherited;
  
  if Assigned(FContainer) then
    FContainer.Notify(Item, Action);
end;

procedure TX2GraphicCollection.Update;
begin
  inherited;

  if Assigned(FContainer) then
    FContainer.Update(Item);
end;


function TX2GraphicCollection.GetItem;
begin
  Result  := TX2GraphicCollectionItem(inherited GetItem(Index));
end;

procedure TX2GraphicCollection.SetItem;
begin
  inherited SetItem(Index, Value);
end;


{==================== TX2GraphicContainer
  Initialization
========================================}
constructor TX2GraphicContainer.Create;
begin
  inherited;

  FGraphics := TX2GraphicCollection.Create(Self);
  FLists    := TList.Create();
end;

destructor TX2GraphicContainer.Destroy;
begin
  FreeAndNil(FGraphics);
  FreeAndNil(FLists);

  inherited;
end;

procedure TX2GraphicContainer.Notification;
begin
  if not Assigned(FLists) then
    exit;

  if Operation = opRemove then
    FLists.Remove(AComponent)
  else
    // In design-time, if a TX2GraphicList is added and it doesn't yet have
    // a container, assign ourselves to it for lazy programmers (such as me :))
    if (Operation = opInsert) and (csDesigning in ComponentState) and
       (AComponent is TX2GraphicList) and
       (not Assigned(TX2GraphicList(AComponent).Container)) then
      TX2GraphicList(AComponent).Container  := Self;

  inherited;
end;

procedure TX2GraphicContainer.Notify;
var
  iList:      Integer;

begin
  case Action of
    cnAdded:
      for iList := FLists.Count - 1 downto 0 do
        TX2GraphicList(FLists[iList]).AddImage(Item.Index);
    cnDeleting:
      for iList := FLists.Count - 1 downto 0 do
        TX2GraphicList(FLists[iList]).DeleteImage(Item.Index);
  end;
end;

procedure TX2GraphicContainer.Update;
var
  iList:      Integer;

begin
  if Assigned(Item) then
    for iList := FLists.Count - 1 downto 0 do
      TX2GraphicList(FLists[iList]).UpdateImage(Item.Index)
  else
    for iList := FLists.Count - 1 downto 0 do
      TX2GraphicList(FLists[iList]).RebuildImages();
end;


procedure TX2GraphicContainer.RegisterList;
begin
  if FLists.IndexOf(AList) = -1 then
    FLists.Add(AList);
end;

procedure TX2GraphicContainer.UnregisterList;
begin
  FLists.Remove(AList);
end;


procedure TX2GraphicContainer.SetGraphics;
begin
  FGraphics.Assign(Value);
end;



{========================= TX2GraphicList
  Initialization
========================================}
constructor TX2GraphicList.Create;
begin
  inherited;

  FBackground   := clBtnFace;
  FStretchMode  := smCrop;
end;

procedure TX2GraphicList.Loaded;
begin
  inherited;

  RebuildImages();
end;


destructor TX2GraphicList.Destroy;
begin
  SetContainer(nil);

  inherited;
end;



{========================= TX2GraphicList
  Graphics
========================================}
procedure TX2GraphicList.CreateImage;
  function DrawGraphic(const ADest: TCanvas; const AIndex: Integer): Boolean;
  var
    rDest:        TRect;

  begin
    Result  := False;
    if not Assigned(FContainer.Graphics[AIndex].Picture) then
      exit;
      
    with FContainer.Graphics[AIndex].Picture do
    begin
      if (FStretchMode = smCrop) or
         ((Width <= Self.Width) and (Height <= Self.Height)) then
        ADest.Draw(0, 0, Graphic)
      else
      begin
        rDest := Rect(0, 0, Width, Height);
        if rDest.Right > Self.Width then
          rDest.Right   := Self.Width;

        if rDest.Bottom > Self.Height then
          rDest.Bottom  := Self.Height;

        ADest.StretchDraw(rDest, Graphic);
      end;
    end;

    Result  := True;
  end;

  function RGBTriple(const AColor: TColor): TRGBTriple;
  var
    cColor:       Cardinal;

  begin
    cColor  := ColorToRGB(AColor);

    with Result do
    begin
      rgbtBlue    := GetBValue(cColor);
      rgbtGreen   := GetGValue(cColor);
      rgbtRed     := GetRValue(cColor);
    end;
  end;

  function SameColor(const AColor1, AColor2: TRGBTriple): Boolean;
  begin
    Result  := CompareMem(@AColor1, @AColor2, SizeOf(TRGBTriple));
  end;

var
  bmpCompare: TBitmap;
  bOk:        Boolean;
  cImage:     TRGBTriple;
  cMask:      TRGBTriple;
  iBit:       Integer;
  iPosition:  Integer;
  iX:         Integer;
  iY:         Integer;
  pCompare:   PRGBTripleArray;
  pImage:     PRGBTripleArray;
  pMask:      PByteArray;

begin
  // Technique used here: draw the image twice, once on the background color,
  // once on black. Loop through the two images, check if a pixel is the
  // background color on one image and black on the other; if so then it's
  // fully transparent. This doesn't eliminate all problems with alpha images,
  // but it's the best option (at least for pre-XP systems).
  //
  // Note that components using ImageList.Draw will have full alpha support,
  // this routine only ensures compatibility with ImageList_Draw components.
  // TMenu is among the first, TToolbar and similar are amongst the latter.
  with AImage do
  begin
    Width               := Self.Width;
    Height              := Self.Height;
    PixelFormat         := pf24bit;

    with Canvas do
    begin
      Brush.Color       := FBackground;
      FillRect(Rect(0, 0, Width, Height));
      bOk               := DrawGraphic(Canvas, AIndex);
    end;
  end;

  with AMask do
  begin
    Width               := Self.Width;
    Height              := Self.Height;
    PixelFormat         := pf1bit;

    with Canvas do
    begin
      Brush.Color       := clBlack;
      FillRect(Rect(0, 0, Width, Height));
    end;
  end;

  // No point in looping through the
  // images if they're blank anyways...
  if not bOk then
    exit;

  bmpCompare  := TBitmap.Create();
  try
    with bmpCompare do
    begin
      Width               := Self.Width;
      Height              := Self.Height;
      PixelFormat         := pf24bit;

      with Canvas do
      begin
        Brush.Color       := clBlack;
        FillRect(Rect(0, 0, Width, Height));
        DrawGraphic(Canvas, AIndex);
      end;
    end;

    cImage  := RGBTriple(FBackground);
    cMask   := RGBTriple(clBlack);

    for iY  := 0 to AImage.Height - 1 do
    begin
      pImage    := AImage.ScanLine[iY];
      pCompare  := bmpCompare.ScanLine[iY];
      pMask     := AMask.ScanLine[iY];
      iPosition := 0;
      iBit      := 128;

      for iX  := 0 to AImage.Width - 1 do
      begin
        if iBit = 128 then
          pMask^[iPosition] := 0;

        if SameColor(pImage^[iX], cImage) and
           SameColor(pCompare^[iX], cMask) then
        begin
          // Transparent pixel
          FillChar(pImage^[iX], SizeOf(TRGBTriple), $00);
          pMask^[iPosition] := pMask^[iPosition] or iBit;
        end;

        iBit  := iBit shr 1;
        if iBit < 1 then
        begin
          iBit  := 128;
          Inc(iPosition);
        end;
      end;
    end;
  finally
    FreeAndNil(bmpCompare);
  end;
end;

procedure TX2GraphicList.AddImage;
var
  bmpImage:       TBitmap;
  bmpMask:        TBitmap;

begin
  if csLoading in ComponentState then
    exit;

  bmpImage  := TBitmap.Create();
  bmpMask   := TBitmap.Create();
  try
    CreateImage(AIndex, bmpImage, bmpMask);
    Assert(AIndex <= Self.Count, 'AAAH! Images out of sync! *panics*');

    if AIndex = Self.Count then
      Add(bmpImage, bmpMask)
    else
      Insert(AIndex, bmpImage, bmpMask);
  finally
    FreeAndNil(bmpMask);
    FreeAndNil(bmpImage);
  end;
end;

procedure TX2GraphicList.UpdateImage;
var
  bmpImage:       TBitmap;
  bmpMask:        TBitmap;

begin
  if csLoading in ComponentState then
    exit;

  bmpImage  := TBitmap.Create();
  bmpMask   := TBitmap.Create();
  try
    CreateImage(AIndex, bmpImage, bmpMask);
    Replace(AIndex, bmpImage, bmpMask);
  finally
    FreeAndNil(bmpMask);
    FreeAndNil(bmpImage);
  end;
end;

procedure TX2GraphicList.DeleteImage;
begin
  Delete(AIndex);
end;


procedure TX2GraphicList.RebuildImages;
var
  iIndex:       Integer;

begin
  if (csLoading in ComponentState) or
     (Width = 0) or (Height = 0) then
    exit;

  Clear();

  if not Assigned(FContainer) then
    exit;

  for iIndex  := 0 to FContainer.Graphics.Count - 1 do
    AddImage(iIndex);
end;


{========================= TX2GraphicList
  Properties
========================================}
procedure TX2GraphicList.DefineProperties;
var
  pType:        TClass;

begin
  // TCustomImageList defines the Bitmap property, we don't want that
  // (since the ImageList will be generated from a GraphicContainer).
  // Erik's solution was to override Read/WriteData, but in Delphi 6 those
  // aren't virtual yet. Instead we skip TCustomImageList's DefineProperties.
  //
  // The trick here is to modify the ClassType so the VMT of descendants
  // (include ourself!) is ignored and only TComponent.DefineProperties
  // is called...
  pType           := Self.ClassType;
  PClass(Self)^   := TComponent;
  try
    DefineProperties(Filer);
  finally
    PClass(Self)^ := pType;
  end;
end;

procedure TX2GraphicList.Notification;
begin
  if (Operation = opRemove) and (AComponent = FContainer) then
    FContainer  := nil;
    
  inherited;
end;


procedure TX2GraphicList.SetBackground;
begin
  FBackground := Value;
  RebuildImages();
end;

procedure TX2GraphicList.SetContainer;
begin
  if Assigned(FContainer) then
    FContainer.UnregisterList(Self);

  FContainer := Value;

  if Assigned(FContainer) then
    FContainer.RegisterList(Self);

  RebuildImages();
end;

procedure TX2GraphicList.SetStretchMode;
begin
  FStretchMode := Value;
  RebuildImages();
end;

end.