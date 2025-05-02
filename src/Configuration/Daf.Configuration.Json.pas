unit Daf.Configuration.Json;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  Daf.Extensions.Configuration,
  Daf.Configuration.ConfigurationProvider,
  Daf.Configuration.Builder;

type
  TJsonConfigurationProvider = class(TConfigurationProvider)
  private
    FFileName: string;
    FSourceOptions: TConfigurationSourceOptions;
    procedure ParseJSONArray(const AParentPath: string; AArray: TJSONArray);
    procedure ParseJSONObject(const AParentPath: string; AObject: TJSONObject);
  public
    constructor Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
    procedure Load; override;
  end;

  TJsonConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FFileName: string;
    FSourceOptions: TConfigurationSourceOptions;
  public
    constructor Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
    function Build(const Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

  JsonConfig = class
  public
    class function AddFile(const Builder: IConfigurationBuilder; const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []): IConfigurationBuilder;
    class function Source(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []): IConfigurationSource;
  end;

implementation
uses
  System.IOUtils;

{ TJsonConfigurationProvider }

constructor TJsonConfigurationProvider.Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
begin
  inherited Create;
  FFileName := AFileName;
  FSourceOptions := SourceOptions;
end;

procedure TJsonConfigurationProvider.Load;
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
begin
  if not FileExists(FFileName) then
  begin
    if (csoOptional in FSourceOptions) then Exit;
    raise Exception.CreateFmt('File "%s" not Found', [FFileName]);
  end;

  Data.Clear;
  JSONValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(FFileName));
  if not Assigned(JSONValue) then
    Exit; // O lanza excepción

  try
    if JSONValue is TJSONObject then
    begin
      JSONObject := TJSONObject(JSONValue);
      ParseJSONObject('', JSONObject);
    end;
  finally
    JSONValue.Free;
  end;

  OnReload; // Notificamos que se ha cargado la config
end;

procedure TJsonConfigurationProvider.ParseJSONObject(const AParentPath: string; AObject: TJSONObject);

  procedure StoreValue(const FullKey, Val: string);
  begin
    Data.AddOrSetValue(FullKey, Val);
  end;

var
  Pair: TJSONPair;
  KeyPath, NewPath: string;
begin
  for Pair in AObject do
  begin
    KeyPath := Pair.JsonString.Value; // Nombre de la propiedad JSON
    if AParentPath <> '' then
      NewPath := TConfigurationPath.Combine([AParentPath, KeyPath])
    else
      NewPath := KeyPath;
    if Pair.JsonValue is TJSONObject then
      // Recursión
      ParseJSONObject(NewPath, Pair.JsonValue as TJSONObject)
    else if Pair.JsonValue is TJSONArray then
      ParseJSONArray(NewPath, Pair.JsonValue as TJSONArray)
    else
      // Valor simple (string, number, boolean, null)
      StoreValue(NewPath, Pair.JsonValue.Value);
  end;
end;

procedure TJsonConfigurationProvider.ParseJSONArray(const AParentPath: string; AArray: TJSONArray);
var
  i: Integer;
  ElemValue: TJSONValue;
  NewPath: string;
begin
  // Cada elemento del array se indexa con su posición: AParentPath:0, AParentPath:1, etc.
  for i := 0 to AArray.Count - 1 do
  begin
    ElemValue := AArray.Items[i];
    NewPath := Format('%s:%d', [AParentPath, i]);
    if ElemValue is TJSONObject then
      ParseJSONObject(NewPath, ElemValue as TJSONObject)
    else if ElemValue is TJSONArray then
      ParseJSONArray(NewPath, ElemValue as TJSONArray)
    else
      // Valor primitivo (string, number, etc.)
      Data.AddOrSetValue(NewPath, ElemValue.Value);
  end;
end;

{ TJsonConfigurationSource }

constructor TJsonConfigurationSource.Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
begin
  inherited Create;
  FFileName := AFileName;
  FSourceOptions := SourceOptions;
end;

function TJsonConfigurationSource.Build(const Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TJsonConfigurationProvider.Create(FFileName, FSourceOptions);
end;

{ JsonConfig }

class function JsonConfig.AddFile(const Builder: IConfigurationBuilder; const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []): IConfigurationBuilder;
begin
  Builder.Add(Source(AFileName, SourceOptions));
  Result := Builder;
end;

class function JsonConfig.Source(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []): IConfigurationSource;
begin
  Result := TJsonConfigurationSource.Create(AFileName, SourceOptions);
end;

end.

