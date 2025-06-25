unit Daf.Web.Render;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  Web.HTTPApp,
  Web.Stencils;

type
  TWebRenderer = class(TComponent)
  private
    FStencilEngine: TWebStencilsEngine;
    FStencilProcessor: TWebStencilsProcessor;
    function EnsureHtmlExt(const FilePath: string): string;
    function ContentFromPath(const SubFolder, FileName: string): string;
    function GetRootDirectory: string;
    procedure SetRootDirectory(const Value: string);
  public
    constructor Create(AOwner: TComponent); override;
    procedure AddVar(const AName: string; AObject: TObject; AOwned: Boolean = True);
    function RenderContent(const Content: string): string;
    function RenderPage(const FileName: string): string;
    function RenderPartial(const FileName: string): string;
    property RootDirectory: string read GetRootDirectory write SetRootDirectory;
  end;

implementation

{ TWebRenderer }

constructor TWebRenderer.Create(AOwner: TComponent);
begin
  inherited;
  FStencilEngine := TWebStencilsEngine.Create(Self);
  FStencilProcessor := TWebStencilsProcessor.Create(Self);
  FStencilProcessor.Engine := FStencilEngine;
end;


function TWebRenderer.GetRootDirectory: string;
begin
  Result := FStencilEngine.RootDirectory;
end;

procedure TWebRenderer.SetRootDirectory(const Value: string);
begin
  FStencilEngine.RootDirectory := Value;
end;

function TWebRenderer.EnsureHtmlExt(const FilePath: string): string;
begin
  if TPath.HasExtension(FilePath) then
    Result := FilePath
  else
    Result := TPath.ChangeExtension(FilePath, '.html');
end;

procedure TWebRenderer.AddVar(const AName: string; AObject: TObject; AOwned: Boolean);
begin
  FStencilProcessor.AddVar(AName, AObject, AOwned);
end;

function TWebRenderer.ContentFromPath(const SubFolder, FileName: string): string;
begin
  var FilePath := TPath.Combine(RootDirectory, SubFolder, FileName);
  FilePath := EnsureHtmlExt(FilePath);

  if not FileExists(FilePath) then
    raise Exception.CreateFmt('Template file not found: %s', [FilePath]);

  Result := FStencilProcessor.ContentFromFile(FilePath);
end;

function TWebRenderer.RenderContent(const Content: string): string;
begin
  FStencilProcessor.InputLines.Text := Content;
  Result := FStencilProcessor.Content;
end;

function TWebRenderer.RenderPage(const FileName: string): string;
begin
  Result := ContentFromPath('pages', FileName);
end;

function TWebRenderer.RenderPartial(const FileName: string): string;
begin
  Result := ContentFromPath('partials', FileName);
end;

end.
