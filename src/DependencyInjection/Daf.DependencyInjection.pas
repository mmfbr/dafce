unit Daf.DependencyInjection;

interface

uses
  System.TypInfo,
  System.Rtti,
  System.Classes,
  System.Generics.Collections,
  Daf.Enumerable,
  DAF.Extensions.DependencyInjection;

type

  TDIObject<T: class> = class(TInterfacedObject)
  {$IFOPT D+}
  strict private
    class var FInstanceCount: Integer;
    class var FInstances: TArray<T>;
  private
    FID: string;
  public
    class property InstanceCount: Integer read FInstanceCount;
    class property Instances: TArray<T> read FInstances;
    property _ID: string read FID;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  {$ENDIF}
  end;

type
{$REGION 'from unit RTTI implem;'}
  PPVtable = ^PVtable;
  PVtable = ^TVtable;
  TVtable = array [0 .. MaxInt div SizeOf(Pointer) - 1] of Pointer;
{$ENDREGION}

  TDescriptorsDictionary = TObjectDictionary<PTypeInfo, TServiceDescriptors>;
  TServiceScope = class;
  // Es un singleton. Contiene la lista de todos los Scopes creados. El primer Scope creado, es
  // el Scope que contiene los sercvicios con lifetime Singleton
  TServiceScopeFactory = class(TDIObject<TServiceScopeFactory>, IServiceScopeFactory, IContainerAccess)
  strict private
    FServiceCollection: IServiceCollectionImpl;
    FScopes: TObjectList<TServiceScope>;
    FSingletonScope: IServiceScope;
    FShutDonwnDone: Boolean;
    function GetSingletonsScope: IServiceScope;
  protected
    procedure Shutdown;
  public
    constructor Create(const ServiceCollection: IServiceCollection);
    destructor Destroy;override;
    function CreateScope: IServiceScope;
    property ServiceCollection: IServiceCollectionImpl read FServiceCollection;
    property SingletonsScope: IServiceScope read GetSingletonsScope;
  end;

  IServiceResolver = interface(IInvokable)
    ['{8B521187-079B-44FE-9124-5A1E6771ECCE}']
    function CreateInstance(const Descriptor: TServiceDescriptor; const Provider: IServiceProvider): IInterface;
    function GetOrCreate(const Descriptor: TServiceDescriptor; const Provider: IServiceProvider): IInterface;overload;
  end;

  TServiceScope = class(TDIObject<TServiceScope>, IServiceScope, IServiceProviderImpl, IServiceResolver)
  private
    FScopeFactory: TServiceScopeFactory;
    [Weak]
    FServiceCollection: IServiceCollectionImpl;
    FServiceInstances : TOrderedDictionary<string, IInterface>;
    FCreateSingletons: TStack<TServiceDescriptor>;
    FIsSingletonsScope: Boolean;
    function GetServiceIdentity(Descriptor: TServiceDescriptor): TServiceIdentity;
    function CreateInstance(const Descriptor: TServiceDescriptor; const Provider: IServiceProvider): IInterface;
    function GetOrCreate(const Descriptor: TServiceDescriptor; const Provider: IServiceProvider): IInterface;overload;
    procedure BeginCreateSingleton(const Descriptor: TServiceDescriptor);
    procedure EndCreateSingleton;
    function GetImplementor(const Descriptor: TServiceDescriptor): IInterface;
    function TryGet(const ServiceType: PTypeInfo; out Service): Boolean;
    function TryGetAll(const ServiceType: PTypeInfo; out Services: IInterfaceList): Boolean;
    function TryGetDescriptors(const ServiceType: PTypeInfo; out Descriptors: TServiceDescriptors): Boolean;
    function GetSingletonsScope: IServiceResolver;
    procedure AddServiceInstance(const Descriptor: TServiceDescriptor; const Service: IInterface);
    function CanResolve(const ServiceType: PTypeInfo): Boolean;
  protected
    property IsSingletonsScope: Boolean read FIsSingletonsScope;
    property ScopeFactory: TServiceScopeFactory read FScopeFactory;
  public
    constructor Create(const Factory: TServiceScopeFactory; const SingletonsScope: Boolean = False);
    destructor Destroy; override;
    procedure Shutdown;
    function CreateScope: IServiceScope;
    function ServiceProvider: IServiceProvider;
    property ServiceCollection: IServiceCollectionImpl read FServiceCollection;
    property SingletonsScope: IServiceResolver read GetSingletonsScope;
  end;

  TServiceCollection = class(TDIObject<TServiceCollection>, IServiceCollectionImpl)
  strict private
    FEntries: TDescriptorsDictionary;
    FIsFrozen: Boolean;
  protected
    function CreateScopeFactory: IServiceScopeFactory;
  public
    constructor Create;
    destructor Destroy; override;
    procedure CheckNotFrozen;
    function GetDescriptors(ServiceType: PTypeInfo): TServiceDescriptors;
    function GetCount: Integer;
    function Add<ServiceType: IInterface>(const LifeTime: TServiceLifeTime; const Factory: TServiceFactory): IServiceCollectionImpl;overload;
    function Add(const ServiceType: PTypeInfo; const LifeTime: TServiceLifeTime; const Factory: TServiceFactory): IServiceCollectionImpl;overload;
    function BuildServiceProvider: IServiceProviderImpl;
    function Contains<T: IInterface>: Boolean;overload;
    function Contains(const ServiceType: PTypeInfo): Boolean;overload;
    property Descriptors[ServiceType: PTypeInfo]: TServiceDescriptors read GetDescriptors;default;
  end;

{$IFOPT D+}
var
  GlobalInstanceCount: Integer;
{$ENDIF}

implementation

uses
  System.SysUtils,
  Daf.Rtti;

{ TDIObject }

{$IFOPT D+}
procedure TDIObject<T>.AfterConstruction;
begin
  inherited;
  FID := TGUID.NewGuid.ToString;
  Setlength(Finstances, 1 + Length(Finstances));
  FInstances[FinstanceCount] := Self as T;
  AtomicIncrement(FInstanceCount);
  AtomicIncrement(GlobalInstanceCount);
end;

procedure TDIObject<T>.BeforeDestruction;
begin
  var FoundIdx := TArray.IndexOf<T>(Finstances, Self as T);
  if FoundIdx > -1 then
  begin
    FInstances[FoundIdx] := nil;
    AtomicDecrement(FInstanceCount);
    AtomicDecrement(GlobalInstanceCount);
    if FinstanceCount = 0 then
      FInstances := nil;
  end;
  inherited;
end;
{$ENDIF}

{ TServiceCollection }

constructor TServiceCollection.Create;
begin
  inherited Create;
  FEntries := TDescriptorsDictionary.Create([doOwnsValues]);
end;

destructor TServiceCollection.Destroy;
begin
  FEntries.Free;
  inherited;
end;

function TServiceCollection.Contains<T>: Boolean;
begin
  Result := Contains(TypeInfo(T));
end;

procedure TServiceCollection.CheckNotFrozen;
begin
  if FIsFrozen then
    raise Exception.Create('This ServiceCollection is frozen and can no longer be modified.');
end;

function TServiceCollection.Contains(const ServiceType: PTypeInfo): Boolean;
begin
  Result := FEntries.ContainsKey(ServiceType);
end;

function TServiceCollection.CreateScopeFactory: IServiceScopeFactory;
begin
  Result := TServiceScopeFactory.Create(Self);
end;

function TServiceCollection.BuildServiceProvider: IServiceProviderImpl;
begin
 if FIsFrozen then
    raise Exception.Create('BuildServiceProvider can only be called once per ServiceCollection.');
  var Factory := CreateScopeFactory;
  var Scope := Factory.CreateScope;
  Result := Scope.ServiceProvider;
  FIsFrozen := True;
end;

function TServiceCollection.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

function TServiceCollection.GetDescriptors(ServiceType: PTypeInfo): TServiceDescriptors;
begin
  Result := FEntries[ServiceType];
end;

function TServiceCollection.Add<ServiceType>(const LifeTime: TServiceLifeTime;
  const Factory: TServiceFactory): IServiceCollectionImpl;
begin
  Result := Add(TypeInfo(ServiceType), LifeTime, Factory);
end;

function TServiceCollection.Add(const ServiceType: PTypeInfo; const LifeTime: TServiceLifeTime;
  const Factory: TServiceFactory): IServiceCollectionImpl;
begin
  CheckNotFrozen;

  Assert(Assigned(Factory), 'ServiceFactory can''t be empty');
  Result := Self;
  var
    Descriptors: TServiceDescriptors;

  if not FEntries.TryGetValue(ServiceType, Descriptors) then
  begin
    Descriptors := TServiceDescriptors.Create;
    FEntries.AddOrSetValue(ServiceType, Descriptors);
  end;
  var Descriptor := TServiceDescriptor.Create(Factory, LifeTime, ServiceType);
  Descriptors.Add(Descriptor);
end;

{ TServiceScopeFactory }

constructor TServiceScopeFactory.Create(const ServiceCollection: IServiceCollection);
begin
  inherited Create;
  FServiceCollection := ServiceCollection;
  FScopes := TObjectList<TServiceScope>.Create(False);
  FSingletonScope := TServiceScope.Create(Self, True);
  FScopes.Add(FSingletonScope as TServiceScope);
  ServiceCollection.AddSingleton<IServiceScopeFactory>(Self);
end;

destructor TServiceScopeFactory.Destroy;
begin
  FreeAndNil(FScopes);
  inherited;
end;

procedure TServiceScopeFactory.Shutdown;
begin
  if FShutDonwnDone then Exit;
  FShutDonwnDone := True;
  var Scopes := FScopes.ToArray;
  FScopes.Clear;
  // los singletons se crean los primeros. Entre ellos esta Self
  for var idx := High(Scopes) downto Low(Scopes) do
  begin
    Scopes[idx].Shutdown;
  end;
end;

function TServiceScopeFactory.CreateScope: IServiceScope;
begin
  var Scope := TServiceScope.Create(Self);
  FScopes.Add(Scope);
  Result := Scope;
end;

function TServiceScopeFactory.GetSingletonsScope: IServiceScope;
begin
  Result := FScopes[0];
end;

{ TServiceScope }

constructor TServiceScope.Create(const Factory: TServiceScopeFactory; const SingletonsScope: Boolean = False);
begin
  inherited Create;
  FServiceInstances := TOrderedDictionary<string, IInterface>.Create;
  FCreateSingletons := TStack<TServiceDescriptor>.Create;
  FIsSingletonsScope := SingletonsScope;
  FScopeFactory := Factory;
  FServiceCollection := Factory.ServiceCollection;
end;

destructor TServiceScope.Destroy;
begin
  FServiceInstances.Free;
  FCreateSingletons.Free;
  inherited;
end;

procedure TServiceScope.AddServiceInstance(const Descriptor: TServiceDescriptor; const Service: IInterface);
begin
  FServiceInstances.Add(GetServiceIdentity(Descriptor), Service);
end;

function TServiceScope.GetOrCreate(const Descriptor: TServiceDescriptor; const Provider: IServiceProvider): IInterface;
begin
  var ServiceIdentity := GetServiceIdentity(Descriptor);
  if FServiceInstances.TryGetValue(ServiceIdentity, Result) then Exit;
  Result := CreateInstance(Descriptor, Provider);
  AddServiceInstance(Descriptor, Result);
end;

function TServiceScope.CreateInstance(const Descriptor: TServiceDescriptor; const Provider: IServiceProvider): IInterface;
begin
  var
  Intf := Descriptor.Factory(Provider);
  if not Supports(Intf, Descriptor.TypeInfo.TypeData.GUID, Result) then
    raise Exception.CreateFmt('% don''t implements %s', [TObject(Intf).QualifiedClassName, Descriptor.ServiceName]);
end;

function TServiceScope.GetServiceIdentity(Descriptor: TServiceDescriptor): TServiceIdentity;
begin
  Result := Descriptor.ServiceName;
end;

function TServiceScope.GetSingletonsScope: IServiceResolver;
begin
  if IsSingletonsScope  then Exit(nil);
  Result := FScopeFactory.SingletonsScope as IServiceResolver;
end;

procedure TServiceScope.Shutdown;
type
  POBject = ^TObject;
begin
  var Services := FServiceInstances.Values.ToArray;
  FServiceInstances.Clear;
  var RCtx := TRttiContext.Create;
  // Los servicios se crean en orden de dependencia
  // preparamos para destruccion haciendo que
  // cada servicio deje de referenciar a otros:
  for var idx := High(Services) downto Low(Services) do
  begin
    var Implementor := Services[idx] as TObject;
    var RImpl := RCtx.GetType(Implementor.ClassInfo);
    var Fields := RImpl.GetFields;
    for var Field in Fields do
    begin
      if not Field.FieldType.IsInterface then Continue;
      var ObjRef := Field.GetValue(Implementor).AsInterface as TObject;
      if ObjRef = nil then Continue;
      if not (ObjRef is TInterfacedObject) then Continue;
      if TInterfacedObject(ObjRef).RefCount <= 0 then
        PObject(PByte(Implementor) + Field.Offset)^ := nil
      else
        Field.SetValue(Implementor, nil);
    end;
    Services[idx] := nil;
  end;
end;

function TServiceScope.ServiceProvider: IServiceProvider;
begin
  Result := Self;
end;

function TServiceScope.CanResolve(const ServiceType: PTypeInfo): Boolean;
begin
  Result := ServiceCollection.Contains(ServiceType);
end;

function TServiceScope.TryGetDescriptors(const ServiceType: PTypeInfo; out Descriptors: TServiceDescriptors): Boolean;
begin
  Descriptors := nil;
  Result := CanResolve(ServiceType);
  if not Result then
    Exit;
  Descriptors := ServiceCollection.GetDescriptors(ServiceType);
end;

function TServiceScope.TryGet(const ServiceType: PTypeInfo; out Service): Boolean;
begin
  Pointer(Service) := nil;
  var
    Descriptors: TServiceDescriptors;
  Result := TryGetDescriptors(ServiceType, Descriptors);
  if not Result then
    Exit;
  var
  Descriptor := ServiceCollection.GetDescriptors(ServiceType).Last;
  IInterface(Service) := GetImplementor(Descriptor);
end;

function TServiceScope.TryGetAll(const ServiceType: PTypeInfo; out Services: IInterfaceList): Boolean;
begin
  Services := TInterfaceList<IInterface>.Create;

  var Descriptors: TServiceDescriptors;
  Result := TryGetDescriptors(ServiceType, Descriptors);
  if not Result then
    Exit;

  for var Descriptor in Descriptors do
    Services.Add(GetImplementor(Descriptor));
end;

function TServiceScope.CreateScope: IServiceScope;
begin
  Result := FScopeFactory.CreateScope;
end;

procedure TServiceScope.BeginCreateSingleton(const Descriptor: TServiceDescriptor);
begin
  FCreateSingletons.Push(Descriptor);
end;

procedure TServiceScope.EndCreateSingleton;
begin
  FCreateSingletons.Pop;
end;

function TServiceScope.GetImplementor(const Descriptor: TServiceDescriptor): IInterface;
begin
  case Descriptor.LifeTime of
    Singleton: try
      BeginCreateSingleton(Descriptor);
      Result := SingletonsScope.GetOrCreate(Descriptor, Self);
    finally
      EndCreateSingleton;
    end;
    Scoped: begin
      if not FCreateSingletons.IsEmpty then
        raise Exception.CreateFmt('singleton %s cannot depends on scoped %s ',[FCreateSingletons.Peek.ServiceName, Descriptor.ServiceName]);
      Result := Self.GetOrCreate(Descriptor, Self);
    end;
    Transient: Result := Self.CreateInstance(Descriptor, Self);
  end;
end;

end.
