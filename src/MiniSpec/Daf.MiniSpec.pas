unit Daf.MiniSpec;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  System.Diagnostics,
  System.Rtti,
  System.Classes,
  Daf.MiniSpec.Types,
  Daf.MiniSpec.Builders,
  Daf.MiniSpec.Reporter,
  Daf.MiniSpec.Expects;

type
{$SCOPEDENUMS ON}
  TOpenOutput = (Never, OnCreate, Always);
  TWaitForUser = (Never, InConsoleReport, Always);
{$SCOPEDENUMS Off}
  TMiniSpec = class
  public
    const Version = '1.0.0';
  strict private
    FFeatures: TList<IFeature>;
    FReporter: ISpecReporter;
    FOutputFile: string;
    FOpenOutputFile: TOpenOutput;
    FWaitForUser: TWaitForUser;
    FTags: string;
    class var FInstance: TMiniSpec;
  public
  protected
    class function CreateSingleton: TMiniSpec;
    class function Instance: TMiniSpec; static;
    procedure ParseArgs;
    function DefaultOutputFile: string;
  public
    constructor Create;
    destructor Destroy; override;
    class destructor ClasDestroy;
    {$REGION 'Fluent api for setup'}
    function Reporter(const Name: string): TMiniSpec;overload;
    function Reporter: ISpecReporter;overload;
    function Tags: string;overload;
    procedure Tags(const Value: string);overload;
    function OutputFile: string;overload;
    function OutputFile(const Filename: string): TMiniSpec;overload;
    function OpenOutputFile: TOpenOutput;overload;
    function OpenOutputFile(const Value: TOpenOutput): TMiniSpec;overload;
    function WaitForUser: TWaitForUser;overload;
    function WaitForUser(const Value: TWaitForUser): TMiniSpec;overload;
    {$ENDREGION}
    procedure Register(Feature: IFeature);
    procedure Run;
 end;

function Expect(const Value: Variant): TExpect;
function Feature(const Description: string): TFeatureBuilder;
function MiniSpec: TMiniSpec;inline;

implementation
uses
  System.IOUtils,
  System.TypInfo,
  Daf.MiniSpec.Utils;

function MiniSpec: TMiniSpec;
begin
  Result := TMiniSpec.Instance;
end;

function Expect(const Value: Variant): TExpect;
begin
  Result := TExpect.Create(Value);
end;

function Feature(const Description: string): TFeatureBuilder;
begin
  Result := TFeatureBuilder.Create(Description);
end;

{ TMiniSpec }

class function TMiniSpec.CreateSingleton: TMiniSpec;
begin
  Result := TMiniSpec.Create;
end;

class function TMiniSpec.Instance: TMiniSpec;
begin
  if not Assigned(FInstance) then
    FInstance := CreateSingleton;
  Result := FInstance;
end;

constructor TMiniSpec.Create;
begin
  inherited;
  FFeatures := TList<IFeature>.Create;
  FReporter := TConsoleReporter.Create;
end;

destructor TMiniSpec.Destroy;
begin
  FFeatures.Free;
  inherited;
end;

function TMiniSpec.OutputFile: string;
begin
  Result := FOutputFile;
end;

class destructor TMiniSpec.ClasDestroy;
begin
  FInstance.Free;
end;

procedure TMiniSpec.Register(Feature: IFeature);
begin
  FFeatures.Add(Feature);
end;

function TMiniSpec.DefaultOutputFile: string;
begin
  Result := TPath.ChangeExtension(ParamStr(0), 'MiniSpec.' + Reporter.GetFileExt);
end;

{$REGION 'Fluent api for setup'}
function TMiniSpec.Reporter(const Name: string): TMiniSpec;
begin
  Result := Self;
  if SameText(Name, 'html') then
    FReporter := THTMLReporter.Create
  else
  if SameText(Name, 'json') then
    FReporter := TJsonReporter.Create
  else
    raise Exception.CreateFmt('Unknow report name: %s', [Name]);
end;

function TMiniSpec.Reporter: ISpecReporter;
begin
  Result := FReporter;
end;

function TMiniSpec.OpenOutputFile(const Value: TOpenOutput): TMiniSpec;
begin
  Result := Self;
  FOpenOutputFile := Value;
end;

function TMiniSpec.OpenOutputFile: TOpenOutput;
begin
  Result := FOpenOutputFile;
end;

function TMiniSpec.OutputFile(const Filename: string): TMiniSpec;
begin
  Result := Self;
  if TPath.IsRelativePath(Filename) then
    FOutputfile := ExpandFileName(TPath.Combine(ExtractFilePath(ParamStr(0)), Filename))
  else
    FOutputfile := FileName;
end;

procedure TMiniSpec.Tags(const Value: string);
begin
  FTags := Value;
end;

function TMiniSpec.WaitForUser: TWaitForUser;
begin
  Result := FWaitForUser;
end;

function TMiniSpec.WaitForUser(const Value: TWaitForUser): TMiniSpec;
begin
  Result := Self;
  FWaitForUser := Value;
end;

function TMiniSpec.Tags: string;
begin
  Result := FTags;
end;
{$ENDREGION}

procedure TMiniSpec.ParseArgs;
var
  idxParam: Integer;
  function NextArg: string;
  begin
    Inc(idxParam);
    if idxParam <= ParamCount then
      Result := ParamStr(idxParam)
    else
      Result := '';
  end;
begin
  idxParam := 0;
  while idxParam <= ParamCount do
  begin
    var Param := NextArg;
    if (Param = '--output') or (Param = '-o') then
      OutputFile(NextArg)
    else if (Param = '--tags') or (Param = '-t') then
      Tags(NextArg)
    else if (Param = '--reporter') or (Param = '-r') then
      Reporter(LowerCase(NextArg));
  end;
end;

procedure TMiniSpec.Run;
begin
  ParseArgs;
  if OutputFile.IsEmpty then
    OutputFile(DefaultOutputFile);

  for var F in FFeatures do
    F.Run;
  Reporter.Report(FFeatures);
  WriteLn(Format('Pass: %d | Fail: %d', [FReporter.PassCount, FReporter.FailCount]));

  if FReporter.UseConsole then
  begin
    if WaitForUser <> TWaitForUser.Never then
    OSShell.WaitForShutdown;
    Exit;
  end;
  var IsNewFile := not TFile.Exists(FOutputFile);
  TFile.WriteAllText(FOutputFile, FReporter.GetContent, TEncoding.UTF8);
  var FileURL := 'file:///' + StringReplace(FOutputfile, '\', '/', [rfReplaceAll]);
  WriteLn('report detail: ' + FileURL);
  if OpenOutputFile = TOpenOutput.Never then Exit;
  if (OpenOutputFile = TOpenOutput.Always) or IsNewFile then
    OSShell.Open(FOutputFile);
  if WaitForUser = TWaitForUser.Always then
    OSShell.WaitForShutdown;
end;

initialization
 TRttiContext.KeepContext;
finalization
 TRttiContext.DropContext;
end.
