unit Daf.Configuration.Memory;

interface

uses
  System.Generics.Collections,
  Daf.Extensions.Configuration,
  Daf.Configuration.ConfigurationProvider,
  Daf.Configuration.Builder;

type
  TMemoryConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FData: TDictionary<string, string>;
    FOwnsData: Boolean;
  public
    constructor Create(const Data: TDictionary<string, string>; const OwnsData: Boolean = True);
    destructor Destroy;override;
    function Build(const Builder: IConfigurationBuilder): IConfigurationProvider;
    property Data: TDictionary<string, string> read FData;
    property OwnsData: Boolean read FOwnsData;
  end;

  TMemoryConfigurationProvider = class(TConfigurationProvider)
  public
    constructor Create(const MemoryConfigurationSource: TMemoryConfigurationSource);
    function TryGet(const Key: string; out Value: string): Boolean; override;
    procedure &Set(const Key, Value: string); override;
  end;

  MemoryConfig = class
  private
  public
    class function AddCollection(const Builder: IConfigurationBuilder; const Data: TDictionary<string, string>=nil): IConfigurationBuilder;
    class function Source(const Data: TDictionary<string,string>=nil): IConfigurationSource;
  end;

implementation

{ TMemoryConfigurationProvider }

constructor TMemoryConfigurationProvider.Create(const MemoryConfigurationSource: TMemoryConfigurationSource);
begin
  inherited Create;
  for var kvp in MemoryConfigurationSource.Data do
    Data.AddOrSetValue(kvp.Key, kvp.Value);
end;

function TMemoryConfigurationProvider.TryGet(const Key: string; out Value: string): Boolean;
begin
  Result := Data.TryGetValue(Key, Value);
end;

procedure TMemoryConfigurationProvider.&Set(const Key, Value: string);
begin
  Data.AddOrSetValue(Key, Value);
end;

{ TMemoryConfigurationSource }

constructor TMemoryConfigurationSource.Create(const Data: TDictionary<string, string>; const OwnsData: Boolean = True);
begin
  inherited Create;
  FOwnsData := OwnsData or not Assigned(Data);
  if Assigned(Data) then
    FData := Data
  else
    FData := TDictionary<string, string>.Create;
end;

destructor TMemoryConfigurationSource.Destroy;
begin
  if OwnsData then
    FData.Free;
  inherited;
end;

function TMemoryConfigurationSource.Build(const Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TMemoryConfigurationProvider.Create(Self);
end;

{ MemoryConfig}

class function MemoryConfig.Source(const Data: TDictionary<string,string>=nil): IConfigurationSource;
begin
  Result := TMemoryConfigurationSource.Create(Data);
end;

class function MemoryConfig.AddCollection(const Builder: IConfigurationBuilder; const Data: TDictionary<string,string>=nil): IConfigurationBuilder;
begin
  Builder.Add(Source(Data));
  Result := Builder;
end;

end.

