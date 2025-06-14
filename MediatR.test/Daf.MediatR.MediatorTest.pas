unit Daf.MediatR.MediatorTest;

interface

uses
  Daf.Extensions.DependencyInjection,
  Daf.MediatR.Contracts,
  DUnitX.TestFramework;

type
  IDependencyMock = interface
    ['{DDBE3375-7995-4983-8683-A4E52529C623}']
    procedure Visit;
    function Visites: Integer;
  end;

  TDependencyMock = class(TInterfacedObject, IDependencyMock)
  private
    FVisites: Integer;
  public
    procedure Visit;
    function Visites: Integer;
  end;

  TPing = class(TInterfacedObject, IRequest<string>)
  end;

  TPingHandler = class(TInterfacedObject, IRequestHandler<string, TPing>)
  private
    FDependency: IDependencyMock;
  public
    constructor Create(const Dependency: IDependencyMock);
    procedure Handle(TRequest: TPing; out Result: string);
  end;

  TJing = class(TInterfacedObject, IRequest)
  end;

  {$REGION 'Handlers'}

  TJingHandler = class(TInterfacedObject, IRequestHandler<TJing>)
  public
    class var Done: Boolean;
    procedure Handle(TRequest: TJing);
  end;

  TPonged = class(TInterfacedObject, INotification)
  end;

  TPongedHandler1 = class(TInterfacedObject, INotificationHandler<TPonged>)
  public
    class var Done: Boolean;
    procedure Handle(Notification: TPonged);
  end;

  TPongedHandler2 = class(TInterfacedObject, INotificationHandler<TPonged>)
  public
    class var Done: Boolean;
    procedure Handle(Notification: TPonged);
  end;

  {$ENDREGION}

  TMediatorTest = class
  protected
    ServiceCollection: IServiceCollection;
    RootProvider: IServiceProvider;
    procedure DebugWrite(Text: string);
  public
    [SetupFixture]
    procedure Setup;

    [TearDownFixture]
    procedure TearDown;
  end;

  [TestFixture]
  TMediatorInRoot = class(TMediatorTest)
  protected
    Mediator: IMediator;
  public
    [SetupFixture]
    procedure Setup;

    [TearDownFixture]
    procedure TearDown;

    [Test]
    procedure Can_Send;

    [Test]
    procedure Can_Send_With_Response;

    [Test]
    procedure Can_Publish;
  end;

  [TestFixture]
  TMediatorInScopes = class(TMediatorTest)
  protected
  public
    [SetupFixture]
    procedure Setup;

    [TearDownFixture]
    procedure TearDown;

    [Test]
    procedure Can_Send_With_Response;
  end;

implementation

uses
  System.Rtti,
  System.SysUtils,
  WinApi.Windows,
  Daf.Rtti,
  Daf.DependencyInjection,
  Daf.MediatR.DependencyInjection;

{ TPingHandler }

constructor TPingHandler.Create(const Dependency: IDependencyMock);
begin
  inherited Create;
  FDependency := Dependency;
end;

procedure TPingHandler.Handle(TRequest: TPing; out Result: string);
begin
  FDependency.Visit;
  Result := 'Pong' + FDependency.Visites.ToString;
end;

{ TJingHandler }

procedure TJingHandler.Handle(TRequest: TJing);
begin
  Done := True;
end;

{ TPongedHandler1 }

procedure TPongedHandler1.Handle(Notification: TPonged);
begin
  TPongedHandler1.Done := True;
end;

{ TPongedHandler2 }

procedure TPongedHandler2.Handle(Notification: TPonged);
begin
  TPongedHandler2.Done := True;
end;

{ TDependencyMock }

procedure TDependencyMock.Visit;
begin
  Inc(FVisites)
end;

function TDependencyMock.Visites: Integer;
begin
  Result := FVisites;
end;


{ TMediatorTest }

procedure TMediatorTest.DebugWrite(Text: string);
begin
  OutputDebugString(PChar(Text));
end;

procedure TMediatorTest.Setup;
begin
  ServiceCollection := TServiceCollection.Create;
  ServiceCollection.AddMediatR;
  ServiceCollection.AddMediatRClasses(_T.PackageOf<TMediatorTest>);
  ServiceCollection.AddScoped<IDependencyMock, TDependencyMock>;
  RootProvider := ServiceCollection.BuildServiceProvider;
  DebugWrite(ServiceCollection.Count.ToString);
  Assert.AreEqual(6, ServiceCollection.Count);
end;

procedure TMediatorTest.TearDown;
begin
  RootProvider := nil;
  ServiceCollection := nil;
  Assert.AreEqual(0, Daf.DependencyInjection.GlobalInstanceCount);
end;

{ TMediatorInRoot }

procedure TMediatorInRoot.Setup;
begin
 inherited;
 Mediator := RootProvider.GetRequiredService<IMediatorImpl>;
end;

procedure TMediatorInRoot.TearDown;
begin
  Mediator := nil;
  inherited;
end;

procedure TMediatorInRoot.Can_Send;
begin
  TJingHandler.Done := False;
  Mediator.Send(TJing.Create);
  Assert.AreEqual(True, TJingHandler.Done);
end;

procedure TMediatorInRoot.Can_Send_With_Response;
begin
  var
  Response := Mediator.Send<string, TPing>(TPing.Create);
  Assert.AreEqual('Pong1', Response);
  var D := RootProvider.GetRequiredService<IDependencyMock>;
  var Ex := D.Visites;
  Assert.AreEqual(1, Ex);
end;

procedure TMediatorInRoot.Can_Publish;
begin
  TPongedHandler1.Done := False;
  TPongedHandler2.Done := False;
  Mediator.Publish(TPonged.Create);
  Assert.AreEqual(True, TPongedHandler1.Done);
  Assert.AreEqual(True, TPongedHandler2.Done);
end;

{ TMediatorInScopes }

procedure TMediatorInScopes.Can_Send_With_Response;
begin
  var
    Scope1 := RootProvider.CreateScope;
  var
    Scope2 := RootProvider.CreateScope;

  var
  Mediator1: IMediator := Scope1.ServiceProvider.GetRequiredService<IMediatorImpl>;
  var
  Mediator2: IMediator := Scope2.ServiceProvider.GetRequiredService<IMediatorImpl>;

  var
  Response := Mediator1.Send<string, TPing>(TPing.Create);
  Assert.AreEqual('Pong1', Response);

  Response := Mediator1.Send<string, TPing>(TPing.Create);
  Assert.AreEqual('Pong2', Response);

  Response := Mediator2.Send<string, TPing>(TPing.Create);
  Assert.AreEqual('Pong1', Response);

  Response := Mediator2.Send<string, TPing>(TPing.Create);
  Assert.AreEqual('Pong2', Response);

  var D := RootProvider.GetRequiredService<IDependencyMock>;
  Assert.AreEqual(0, D.Visites);
  var D1 := Scope1.ServiceProvider.GetRequiredService<IDependencyMock>;
  Assert.AreEqual(2, D1.Visites);
  var D2 := Scope2.ServiceProvider.GetRequiredService<IDependencyMock>;
  Assert.AreEqual(2, D2.Visites);

  Assert.AreNotEqual(D1, D2);
end;

procedure TMediatorInScopes.Setup;
begin
  inherited;
end;

procedure TMediatorInScopes.TearDown;
begin
  inherited;
end;

initialization

TDUnitX.RegisterTestFixture(TMediatorInRoot);

end.
