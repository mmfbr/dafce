unit Daf.Commons.Config.Test;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Rtti,
  DUnitX.TestFramework;



implementation
(*
type
  TCmdLnParams = class(TInterfacedObject, IConfigurationSection, IConfiguration)
  private
    [Weak]
    FParent: IConfiguration;
    FKey: string;
    FValue: TValue;
    FChildren: TDictionary<string, IConfiguration>;
    function GetKey: string;
    function GetPath: string;
    function GetItem(key: string): TValue;
    procedure SetItem(key: string; const value: TValue);
    function GetValue: TValue;
    procedure SetValue(const value: TValue);
    function GetParent: IConfiguration;
    function GetCommand: string;
  protected
    function GetPathValue(Segments: TArray<string>): TValue;
  public
    constructor Create(const key: string = ''; const Parent: IConfiguration = nil);
    destructor Destroy; override;
    function AddSection(const key: string): TCmdLnParams;
    function HasItem(key: string): Boolean;
    function HasSections: Boolean;
    function GetSection(const Key: string): IConfiguration;
    function GetSections: TEnumerable<IConfiguration>;
    property Parent: IConfiguration read GetParent;
    property Command: string read GetCommand;
    property Path: string read GetPath;
    property Key: string read GetKey;
    property Value: TValue read GetValue write SetValue;
    property Item[key: string]: TValue read GetItem write SetItem;
  end;

  { TCmdLnParams }

constructor TCmdLnParams.Create(const key: string = ''; const Parent: IConfiguration = nil);
begin
  inherited Create;
  FParent := Parent;
  FKey := key;
  FChildren := TDictionary<string, IConfiguration>.Create;
end;

destructor TCmdLnParams.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TCmdLnParams.GetSections: TEnumerable<IConfiguration>;
begin
  Result := FChildren.Values;
end;

function TCmdLnParams.GetValue: TValue;
begin
  Result := FValue;
end;

procedure TCmdLnParams.SetValue(const value: TValue);
begin
  FValue := value;
  FChildren.Clear;
end;

function TCmdLnParams.AddSection(const key: string): TCmdLnParams;
begin
  Result := TCmdLnParams.Create(key, Self);
  FChildren.Add(key, Result);
  FValue := TValue.Empty;
end;

function TCmdLnParams.GetSection(const Key: string): IConfiguration;
begin
  var
    Opts: IConfiguration;
  if not FChildren.TryGetValue(key, Opts) then
    Opts := AddSection(key);
  Result := Opts;
end;

procedure TCmdLnParams.SetItem(key: string; const value: TValue);
begin
  GetSection(key).value := value;
end;

function TCmdLnParams.GetParent: IConfiguration;
begin
  Result := FParent;
end;

function TCmdLnParams.GetPath: string;
begin
  if Parent = nil then
    Result := Key
  else
    Result := Parent.Path + ':' + Key;
end;

function TCmdLnParams.GetPathValue(Segments: TArray<string>): TValue;
begin
  var
  Len := Length(Segments);
  case Len of
    0:
      Result := TValue.Empty;
    1:
      Result := GetSection(Segments[0]).value;
  else
    begin
      var
      Section := TCmdLnParams(GetSection(Segments[0]));
      var
        NewSegments: TArray<string>;
      SetLength(NewSegments, Len - 1);
      TArray.Copy<string>(Segments, NewSegments, 1, 0, Len - 1);
      Result := Section.GetPathValue(NewSegments);
    end;
  end;
end;

function TCmdLnParams.GetCommand: string;
begin
  for var Sec in GetSections do
  begin
    if not HasItem(Sec.key) then
      Exit(Sec.key);
  end;
  Result := '';
end;

function TCmdLnParams.GetItem(key: string): TValue;
begin
  var
  Segments := key.Split(['.']);
  Result := GetPathValue(Segments);
end;

function TCmdLnParams.GetKey: string;
begin
  Result := FKey;
end;

function TCmdLnParams.HasItem(key: string): Boolean;
begin
  Result := FChildren.ContainsKey(key) and not FChildren[key].HasSections;
end;

function TCmdLnParams.HasSections: Boolean;
begin
  Result := not FChildren.IsEmpty;
end;

{ TConfigItem }

procedure TConfigItem.Can_Add_Item;
begin

end;

{ TConfigSpec }

procedure TConfigSpec.Setup;
begin
  Config := TCmdLnParams.Create;
end;

procedure TConfigSpec.TearDown;
begin

end;

*)

end.
