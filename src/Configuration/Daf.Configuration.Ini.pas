unit Daf.Configuration.Ini;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.Generics.Collections,
  Daf.Extensions.Configuration,
  Daf.Configuration.ConfigurationProvider,
  Daf.Configuration.Builder;

type
  /// <summary>
  /// Proveedor para cargar configuración desde un archivo .ini
  /// </summary>
  TIniConfigurationProvider = class(TConfigurationProvider)
  private
    FFileName: string;
    FSourceOptions: TConfigurationSourceOptions;
  public
    constructor Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
    procedure Load; override;
  end;

  /// <summary>
  /// Source para crear el proveedor anterior
  /// </summary>
  TIniConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FFileName: string;
    FSourceOptions: TConfigurationSourceOptions;
  public
    constructor Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
    function Build(const Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

  IniConfig = class
  public
    class function AddFile(const Builder: IConfigurationBuilder; const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []): IConfigurationBuilder;
    class function Source(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []): IConfigurationSource;
  end;

implementation

{ TIniConfigurationProvider }

constructor TIniConfigurationProvider.Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
begin
  inherited Create;
  FFileName := AFileName;
  FSourceOptions := SourceOptions;
end;

procedure TIniConfigurationProvider.Load;
var
  Ini: TIniFile;
  Sections, Keys: TStrings;
  Section, Key, FullKey, Value: string;
  i, j: Integer;
begin
  if not FileExists(FFileName) then
  begin
    if (csoOptional in FSourceOptions) then Exit;
    raise Exception.CreateFmt('File "%s" not Found', [FFileName]);
  end;

  Data.Clear;
  Ini := TIniFile.Create(FFileName);
  Keys := TStringList.Create;
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for i := 0 to Sections.Count - 1 do
    begin
      Section := Sections[i];
      Keys.Clear;
      Ini.ReadSection(Section, Keys);
      for j := 0 to Keys.Count - 1 do
      begin
        Key := Keys[j];
        Value := Ini.ReadString(Section, Key, '');
        if Section.IsEmpty then
          FullKey := Key
        else
          FullKey := TConfigurationPath.Combine([Section, Key]);
        Data.AddOrSetValue(FullKey, Value);
      end;
    end;
  finally
    Ini.Free;
    Sections.Free;
    Keys.Free;
  end;
  OnReload;
end;

{ TIniConfigurationSource }

constructor TIniConfigurationSource.Create(const AFileName: string; const SourceOptions: TConfigurationSourceOptions = []);
begin
  inherited Create;
  FFileName := AFileName;
  FSourceOptions := SourceOptions;
end;

function TIniConfigurationSource.Build(const Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TIniConfigurationProvider.Create(FFileName, FSourceOptions);
end;

{ IniConfig }

class function IniConfig.AddFile(const Builder: IConfigurationBuilder; const AFileName: string;
  const SourceOptions: TConfigurationSourceOptions): IConfigurationBuilder;
begin
  Builder.Add(Source(AFileName, SourceOptions));
  Result := Builder;
end;

class function IniConfig.Source(const AFileName: string; const SourceOptions: TConfigurationSourceOptions): IConfigurationSource;
begin
  Result := TIniConfigurationSource.Create(AFileName);
end;

end.

