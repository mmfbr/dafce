unit Daf.Commons.Activator.Tests;

interface

uses
  DUnitX.TestFramework;

type
  // Activation requires RTTI
  {$TYPEINFO ON}
  TActivatable = class
  private
    FValue: Integer;
  public
    constructor Create;overload;
    constructor Create(const AValue: Integer);overload;
    property Value: Integer read FValue write FValue;
  end;
  {$TYPEINFO OFF}

  TActivator_Test = class
  protected
    FActivated: TActivatable;
  public
    [TearDown]
    procedure TearDown;
  end;

  [TestFixture]
  Can_Activate_With_DefaultCtor = class(TActivator_Test)
  public
    [Test]
    procedure FromTypeInf;
    [Test]
    procedure FromClass;
    [Test]
    procedure FromGeneric;
  end;

  [TestFixture]
  Cana_activate_with_arg_Integer = class(TActivator_Test)
    [Test]
    procedure FromClass;
    [Test]
    procedure FromGeneric;
  end;

implementation

uses
  Daf.Activator;

{ TActivator_Test }

procedure TActivator_Test.TearDown;
begin
  FActivated.Free;
end;

{ TActivator_DefaultCtor_Test }

procedure Can_Activate_With_DefaultCtor.FromClass;
begin
  FActivated := TActivator.CreateInstance(TActivatable) as TActivatable;
  Assert.IsNotNull(FActivated);
  Assert.AreEqual(1, FActivated.Value);
end;

procedure Can_Activate_With_DefaultCtor.FromGeneric;
begin
  FActivated := TActivator.CreateInstance<TActivatable>;
  Assert.IsNotNull(FActivated);
  Assert.AreEqual(1, FActivated.Value);
end;

procedure Can_Activate_With_DefaultCtor.FromTypeInf;
begin
  FActivated := TActivator.CreateInstance(TypeInfo(TActivatable)) as TActivatable;
  Assert.IsNotNull(FActivated);
  Assert.AreEqual(1, FActivated.Value);
end;

{ TActivatedObject }

constructor TActivatable.Create;
begin
  inherited;
  Create(1);
end;

constructor TActivatable.Create(const AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
end;

{ TActivator_With_Integer_Arg_Test }

procedure Cana_activate_with_arg_Integer.FromClass;
begin
  FActivated := TActivator.CreateInstance(TActivatable, [2]) as TActivatable;
  Assert.IsNotNull(FActivated);
  Assert.AreEqual(2, FActivated.Value);
end;

procedure Cana_activate_with_arg_Integer.FromGeneric;
begin
  FActivated := TActivator.CreateInstance<TActivatable>([2]) as TActivatable;
  Assert.IsNotNull(FActivated);
  Assert.AreEqual(2, FActivated.Value);
end;

initialization

TDUnitX.RegisterTestFixture(Can_Activate_With_DefaultCtor);
TDUnitX.RegisterTestFixture(Cana_activate_with_arg_Integer);

end.
