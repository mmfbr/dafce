unit Daf.DependencyInjectionTest;

interface

uses
  System.TypInfo,
  System.RTTI,
  DUnitX.TestFramework,
  Daf.DependencyInjection,
  Daf.MemUtils;

type
  ITestableService = interface(IInterface)
    ['{F88F262A-6591-452C-BC93-E5D2DAA48875}']
    function GetRefCount: Integer;
    function GetImplementorClass: TClass;
    function GetValue: string;
    procedure SetValue(const Value: string);
    property Value: string read GetValue write SetValue;
  end;


  [TestFixture]
  [Category('Daf,DependencyInjection')]
  TDependencyInjectionTest = class(TObject)
  private
    FServiceCollection: IServiceCollection;
    FServiceProvider: IServiceProvider;
  private
    property ServiceCollection: IServiceCollection read FServiceCollection;
    property ServiceProvider: IServiceProvider read FServiceProvider;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  end;

  [TestFixture]
  TAddServiceTest = class(TDependencyInjectionTest)
  private
    ObtainedService: IInterface;
    function FactoryMethod(ServiceProvider: IServiceProvider): IInterface;
    procedure ValidateObtainedService;
  public

    [Test]
    procedure Cleanup_test;

    [Test]
    procedure Can_use_a_ImplmentorClass;

    [Test]
    procedure Can_use_a_Factory_Method;

    [Test]
    procedure Can_use_a_Factory_Func;

  end;

  [TestFixture]
  TLifTimeTest = class(TDependencyInjectionTest)
  public
    [Test]
    procedure Cann_add_a_Service_Transient;

    [Test]
    procedure Cann_get_a_Service_Transient;

    [Test]
    procedure Cann_add_a_Service_Singleton;

    [Test]
    procedure Singleton_must_get_only_one_Service;

    [Test]
    procedure Transient_must_get_new_service_each_time;
  end;

  [TestFixture]
  TSopedLifeTime = class(TDependencyInjectionTest)
  public
    [Test]
    procedure Cann_add_an_Spcoed_Service;
    [Test]
    procedure Must_get_unique_instance_for_each_scope;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.Threading,
  Daf.DependencyInjection;

type
  TTestableService = class(TDIObject<TTestableService>, ITestableService)
  private
    FValue: string;
  public
    procedure AfterConstruction; override;
    function GetImplementorClass: TClass;
    function GetValue: string;
    procedure SetValue(const Value: string);
    property Value: string read GetValue write SetValue;
  end;

  TOtherTestableService = class(TTestableService);


  { TTestableService }

procedure TTestableService.AfterConstruction;
begin
  inherited;
  FValue := 'value is not assigned';
end;

function TTestableService.GetImplementorClass: TClass;
begin
  Result := Self.ClassType;
end;

function TTestableService.GetValue: string;
begin
  Result := FValue;
end;

procedure TTestableService.SetValue(const Value: string);
begin
  FValue := Value;
end;

{ TDependencyInjectionTest }

procedure TDependencyInjectionTest.Setup;
begin
  FServiceCollection := TServiceCollection.Create;
  FServiceProvider := FServiceCollection.BuildServiceProvider;

  Assert.AreEqual(1, TServiceCollection.InstanceCount);
  Assert.AreEqual(1, TServiceScopeFactory.InstanceCount);
  Assert.AreEqual(2, TServiceScope.InstanceCount);
  Assert.AreEqual(1, TServiceProvider.InstanceCount);
end;

procedure TDependencyInjectionTest.TearDown;
begin
  FServiceProvider := nil;
  FServiceCollection := nil;
  Assert.AreEqual(0, TServiceCollection.InstanceCount);
  Assert.AreEqual(0, TServiceScopeFactory.InstanceCount);
  Assert.AreEqual(0, TServiceScope.InstanceCount);
  Assert.AreEqual(0, TServiceProvider.InstanceCount);
end;

{ TAddServiceTest }

function FactoryFunc(ServiceProvider: IServiceProvider): IInterface;
begin
  Result := TTestableService.Create;
end;

function TAddServiceTest.FactoryMethod(ServiceProvider: IServiceProvider): IInterface;
begin
  Result := TTestableService.Create;
end;

procedure TAddServiceTest.ValidateObtainedService;
begin
  Assert.Implements<ITestableService>(ObtainedService);
  Assert.AreEqual(TTestableService, (ObtainedService as ITestableService).GetImplementorClass);
end;

procedure TAddServiceTest.Cleanup_test;
begin
  Assert.AreEqual(0,0);
end;

procedure TAddServiceTest.Can_use_a_Factory_Func;
begin
  ServiceCollection.AddTransient(TypeInfo(ITestableService), FactoryFunc);
  ServiceProvider.Get(TypeInfo(ITestableService), ObtainedService);
  ValidateObtainedService;
end;

procedure TAddServiceTest.Can_use_a_Factory_Method;
begin
  ServiceCollection.AddTransient(TypeInfo(ITestableService), FactoryMethod);
  ServiceProvider.Get(TypeInfo(ITestableService), ObtainedService);
  ValidateObtainedService;
end;

procedure TAddServiceTest.Can_use_a_ImplmentorClass;
begin
  ServiceCollection.AddTransient<ITestableService, TTestableService>();
  ServiceProvider.Get(TypeInfo(ITestableService), ObtainedService);
  ValidateObtainedService;
end;

{ TLifTimeTest }

procedure TLifTimeTest.Cann_add_a_Service_Transient;
begin
  var SavedCount := ServiceCollection.Count;
  ServiceCollection.AddTransient<ITestableService, TTestableService>();
  Assert.AreEqual(SavedCount + 1, ServiceCollection.Count);
end;

procedure TLifTimeTest.Cann_get_a_Service_Transient;
begin
  ServiceCollection.AddTransient<ITestableService, TTestableService>();
  var
  Tester1 :=  ServiceProvider.Get<ITestableService>;
  Assert.AreEqual(1, TTestableService.InstanceCount);
  Tester1 := nil;
  Assert.AreEqual(0, TTestableService.InstanceCount);
end;

procedure TLifTimeTest.Cann_add_a_Service_Singleton;
begin
  var SavedCount := ServiceCollection.Count;
  ServiceCollection.AddSingleton<ITestableService, TTestableService>();
  Assert.AreEqual(SavedCount + 1, ServiceCollection.Count);
end;

procedure TLifTimeTest.Singleton_must_get_only_one_Service;
begin
  ServiceCollection.AddSingleton<ITestableService, TTestableService>();
  var Tester1 := ServiceProvider.Get<ITestableService>;
  var Tester2 := ServiceProvider.Get<ITestableService>;
  Assert.AreEqual(1, TTestableService.InstanceCount);
  Assert.AreEqual(Tester1, Tester2);
  Tester1 := nil;
  Tester2 := nil;
  Assert.AreEqual(1, TTestableService.InstanceCount);
end;

procedure TLifTimeTest.Transient_must_get_new_service_each_time;
begin
  ServiceCollection.AddTransient<ITestableService, TTestableService>();
  var Tester1 := ServiceProvider.Get<ITestableService>;
  var Tester2 := ServiceProvider.Get<ITestableService>;
  Assert.AreEqual(2, TTestableService.InstanceCount);
  Assert.AreNotEqual(Tester1, Tester2);
  Tester1 := nil;
  Tester2 := nil;
  Assert.AreEqual(0, TTestableService.InstanceCount);
end;

{ TSopedLifeTime }

procedure TSopedLifeTime.Cann_add_an_Spcoed_Service;
begin
  ServiceCollection.AddScoped<ITestableService,TTestableService>;
  var Tester1 := ServiceProvider.Get<ITestableService>();
  var Tester2 := ServiceProvider.Get<ITestableService>();
  Assert.AreEqual(1, TTestableService.InstanceCount);
end;

procedure TSopedLifeTime.Must_get_unique_instance_for_each_scope;
begin
  ServiceCollection.AddScoped<ITestableService,TTestableService>;
  ServiceProvider.Get<ITestableService>();
  var Tester0_1 := ServiceProvider.Get<ITestableService>;
  var Tester0_2 := ServiceProvider.Get<ITestableService>;
  Assert.AreEqual(1, TTestableService.InstanceCount);

  var Scope1 := ServiceProvider.CreateScope;
  var Scope2 := ServiceProvider.CreateScope;

  var Tester1_1 := Scope1.ServiceProvider.Get<ITestableService>;
  var Tester1_2 := Scope1.ServiceProvider.Get<ITestableService>;
  Assert.AreEqual(2, TTestableService.InstanceCount);

  var Tester2_1 := Scope2.ServiceProvider.Get<ITestableService>;
  var Tester2_2 := Scope2.ServiceProvider.Get<ITestableService>;
  Assert.AreEqual(3, TTestableService.InstanceCount);
end;

end.
