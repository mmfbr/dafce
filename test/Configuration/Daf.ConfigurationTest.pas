unit Daf.ConfigurationTest;

interface

uses
  DUnitX.TestFramework;

type
  TMyConfigClass = class
  private
    FNamedProperty: string;
    procedure SetNamedProperty(const Value: string);
  public
    property NamedProperty: string read FNamedProperty write SetNamedProperty;
  end;

  TConfigSpec = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  end;

  [TestFixture]
  ConfigurationBuilder = class(TConfigSpec)
  public
    procedure Can_bind_From_Dict;
  end;

implementation

uses

  System.Generics.Collections,
  System.SysUtils,
  Daf.Extensions.Configuration,
  Daf.Configuration.Builder;

  { TMyConfigClass }

procedure TMyConfigClass.SetNamedProperty(const Value: string);
begin
  FNamedProperty := Value;
end;

{ TConfigSpec }

procedure TConfigSpec.Setup;
begin

end;

procedure TConfigSpec.TearDown;
begin

end;

{ ConfigurationBuilder }

procedure ConfigurationBuilder.Can_bind_From_Dict;
begin
  var
  Dic := TDictionary<string, string>.Create;
  Dic.Add('namedproperty', 'value for named property');
  var IConfigurationBuilder:= TConfigurationBuilder.Create;

  (*

    .AddInMemoryCollection(dic)
    .Build();

    var options = config.Get<MyClass>();
    Console.WriteLine(options.NamedProperty); // returns "value for named property"
  *)
end;


initialization

TDUnitX.RegisterTestFixture(ConfigurationBuilder);

end.
