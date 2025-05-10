unit Daf.Extensions.DependencyInjection;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.TypInfo,
  Daf.Enumerable;

type
  IServiceProviderImpl = interface;
  IServiceScope = interface;

  EServiceProviderError = class(Exception)
  end;

  // Interfaces don't support generic overload, so we model our desired interface using a record
  // that will delegate behavior in a true interface that implementor classes will support
  IServiceProvider = record
  strict private
    FImplementor: IServiceProviderImpl;
    class function Error(const Fmt: string; const Args: array of const): EServiceProviderError; static;
  private
    function GetFromInterfaceOps(const ServiceType: PTypeInfo): TArray<TRttiMethod>;
  public
    class operator Equal(S: IServiceProvider; P: Pointer): Boolean;
    class operator NotEqual(S: IServiceProvider; P: Pointer): Boolean;
    class operator Implicit(const Implementor: IServiceProviderImpl): IServiceProvider;
    class operator Implicit(const Provider: IServiceProvider): IServiceProviderImpl;
    function AsType<ServiceType: IInterface>: ServiceType;

    function CanResolve(const ServiceType: PTypeInfo): Boolean;

    procedure GetService(const ServiceType: PTypeInfo; out Service); overload;
    function GetService<ServiceType: IInterface>: ServiceType; overload;

    procedure GetRequiredService(const ServiceType: PTypeInfo; out Service);overload;
    function GetRequiredService<ServiceType>: ServiceType;overload;

    function GetServices(const ServiceType: PTypeInfo): IInterfaceList<IInterface>;overload;
    function GetServices<ServiceType: IInterface>: IInterfaceList<ServiceType>; overload;

    function TryGet(const ServiceType: PTypeInfo; out Service): Boolean;overload;
    function TryGet<ServiceType: IInterface>(out Service): Boolean;overload;
    function CreateScope: IServiceScope;
  end;

  TServiceFactory<ServiceType: IInterface> = reference to function(Provider: IServiceProvider): ServiceType;
  TServiceFactory = TServiceFactory<IInterface>;
  Factory = class
  public
    class function From(const ServiceType: PTypeInfo; const TImpl: TClass): TServiceFactory;overload;
    class function From(const ServiceType: PTypeInfo; const Implementor: IInterface): TServiceFactory;overload;
  end;

  TServiceLifeTime = (Singleton, Scoped, Transient);
  TServiceIdentity = string;

  IContainerAccess = interface(IInvokable)
    ['{606B658C-C5EB-48D6-B447-D9A19CBB31F5}']
    procedure Shutdown;
  end;

  TServiceDescriptor = record
  strict private
    FFactory: TServiceFactory;
    FLifeTime: TServiceLifeTime;
    FTypeInfo: PTypeInfo;
  public
    constructor Create(const Factory: TServiceFactory; const LifeTime: TServiceLifeTime; const TypeInfo: PTypeInfo);
    function ServiceName: string;
    property Factory: TServiceFactory read FFactory;
    property LifeTime: TServiceLifeTime read FLifeTime;
    property TypeInfo: PTypeInfo read FTypeInfo;
  end;
  TServiceDescriptors = TList<TServiceDescriptor>;

  // misteriosamente si uso interface(IInvokable) se produce E2134 Type'<void>' has no type info
{$M+}
  IServiceProviderImpl = interface
    ['{D2043968-561D-4666-8A36-D2714BC262C4}']
    function CanResolve(const ServiceType: PTypeInfo): Boolean;
    function TryGet(const ServiceType: PTypeInfo; out Service): Boolean;
    function TryGetAll(const ServiceType: PTypeInfo; out Services: IInterfaceList): Boolean;
    function CreateScope: IServiceScope;
  end;
{$M-}

  IServiceCollectionImpl = interface(IInvokable)
    ['{C767E76F-F5AE-438D-9725-B624E704127B}']
    function GetCount: Integer;
    function Add(const ServiceType: PTypeInfo; const LifeTime: TServiceLifeTime; const ServiceFactory: TServiceFactory): IServiceCollectionImpl; overload;
    function Contains(const ServiceType: PTypeInfo): Boolean;
    function BuildServiceProvider: IServiceProviderImpl;
    function GetDescriptors(ServiceType: PTypeInfo): TServiceDescriptors;
  end;

  IServiceScope = interface(IInvokable)
    ['{E0B2F2D2-BAF3-4C6F-9B22-4A9B2B3A5C4D}']
    function ServiceProvider: IServiceProvider;
  end;

  IServiceScopeFactory = interface(IInvokable)
    ['{C3F2E1D4-7A6C-4B8E-9B12-5D8A6A2D9F3E}']
    function CreateScope: IServiceScope;
  end;

  IServiceCollection = record
  strict private
    FImplementor: IServiceCollectionImpl;
    function GetCount: Integer;
  public
    class operator Implicit(const Implementor: IServiceCollectionImpl): IServiceCollection;
    class operator Implicit(const ServiceCollection: IServiceCollection): IServiceCollectionImpl;
    function BuildServiceProvider: IServiceProvider;

    function Contains<ServiceType: IInterface>: Boolean;overload;
    function Contains(const ServiceType: PTypeInfo): Boolean;overload;

    function Add(const LifeTime: TServiceLifeTime; const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection; overload;
    function Add<ServiceType: IInterface>(const LifeTime: TServiceLifeTime; const Factory: TServiceFactory<ServiceType>)
      : IServiceCollection; overload;

    function AddSingleton(const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection; overload;
    function AddSingleton<ServiceType: IInterface>(const Factory: TServiceFactory<ServiceType>): IServiceCollection; overload;

    function AddSingleton(const ServiceType: PTypeInfo; const TImpl: TClass): IServiceCollection;overload;
    function AddSingleton<ServiceType: IInterface; TImpl: ServiceType>: IServiceCollection; overload;

    function AddSingleton(const ServiceType: PTypeInfo; const Implementor: IInterface): IServiceCollection; overload;
    function AddSingleton<ServiceType: IInterface>(const Implementor: ServiceType): IServiceCollection; overload;

    function AddTransient(const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection; overload;
    function AddTransient(const ServiceType: PTypeInfo; const TImpl: TClass): IServiceCollection;overload;
    function AddTransient<ServiceType: IInterface>(const Factory: TServiceFactory<ServiceType>): IServiceCollection; overload;
    function AddTransient<ServiceType: IInterface; TImpl: ServiceType>: IServiceCollection; overload;

    function AddScoped(const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection; overload;
    function AddScoped(const ServiceType: PTypeInfo; const TImpl: TClass): IServiceCollection;overload;
    function AddScoped<ServiceType: IInterface>(const Factory: TServiceFactory<ServiceType>): IServiceCollection; overload;
    function AddScoped<ServiceType: IInterface; TImpl: ServiceType>: IServiceCollection; overload;
    property Count: Integer read GetCount;
  end;

  TLazy<T: IInvokable> = class(TVirtualInterface)
  private
    FServiceProvider: IServiceProvider;
    FDelegated: T;
    FType: PTypeInfo;
    FFactory: TServiceFactory<T>;
    procedure CallInterceptor(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
    procedure CallDelegated(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue);
    procedure CheckDelegatedReady;
  public
    constructor Create(ServiceProvider: IServiceProvider; const Factory: TServiceFactory<T>);
  end;

  Lazy = record
    class function From<T: IInvokable>(Provider: IServiceProvider; const Factory: TServiceFactory<T>): T;static;
  end;

  TDuckDecorator<T: IInvokable> = class(TVirtualInterface)
  private
    FDecorated: T;
    FDecoratedType: PTypeInfo;
    procedure CallInterceptor(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
  protected
    procedure CallDecorated(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue);
    function CallByNameTo(const Instance: TObject; MethodName: string; const Args: TArray<TValue>; var CallResult: TValue): Boolean;
    procedure BeforeCall(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue); virtual;
    procedure AfterCall(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue); virtual;
    constructor InternalCreate(const DecoratedType: PTypeInfo; const Decorated: T);
  public
    constructor Create(Decorated: T); overload;
    constructor Create; overload;
    destructor Destroy; override;
    property Decorated: T read FDecorated write FDecorated;
    property DecoratedType: PTypeInfo read FDecoratedType;
  end;

  TDuckDecorator = class(TDuckDecorator<IInvokable>)
  public
    constructor Create(const DecoratedType: PTypeInfo; Decorated: IInvokable = nil);
  end;

implementation

uses
  Daf.Rtti,
  Daf.MemUtils,
  Daf.Activator,
  Daf.DependencyInjection.ActivatorUtilities;

{ TServiceDescriptor }

constructor TServiceDescriptor.Create(const Factory: TServiceFactory; const LifeTime: TServiceLifeTime;
  const TypeInfo: PTypeInfo);
begin
  FFactory := Factory;
  FLifeTime := LifeTime;
  FTypeInfo := TypeInfo;
 end;


function TServiceDescriptor.ServiceName: string;
begin
  var RC := TRttiContext.Create;
  try
    var RType := RC.GetType(TypeInfo);
    Result :=   RType.QualifiedName;
  finally
    RC.Free;
  end;
end;

{ IServiceProvider }

class operator IServiceProvider.Implicit(const Implementor: IServiceProviderImpl): IServiceProvider;
begin
  Result.FImplementor := Implementor;
end;

class operator IServiceProvider.Implicit(const Provider: IServiceProvider): IServiceProviderImpl;
begin
  Result := Provider.FImplementor;
end;

class function IServiceProvider.Error(const Fmt: string; const Args: array of const): EServiceProviderError;
begin
  Result := EServiceProviderError.CreateFmt(Fmt, Args);
end;

function IServiceProvider.TryGet(const ServiceType: PTypeInfo; out Service): Boolean;
begin
  Result := FImplementor.TryGet(ServiceType, Service);
  if Result then Exit;
  var Conversors := GetFromInterfaceOps(ServiceType);
  for var Conversor in Conversors do
  begin
    Result := FImplementor.TryGet(Conversor.GetParameters[0].ParamType.Handle, Service);
    if Result then
    begin
      var Arg: TValue;
      TValue.Make(@Service, Conversor.GetParameters[0].ParamType.Handle, Arg);
      var Instance: TValue;
      TValue.Make(nil, ServiceType, Instance);
      Instance := Conversor.Invoke(Instance, [Arg]);
      Instance.ExtractRawData(@Service);
      Exit;
    end;
  end;
end;

function IServiceProvider.TryGet<ServiceType>(out Service): Boolean;
begin
  Result := TryGet(TypeInfo(ServiceType), Service);
end;

procedure IServiceProvider.GetService(const ServiceType: PTypeInfo; out Service);
begin
  if not TryGet(ServiceType, Service) then
    IInterface(Service) := nil;
end;

function IServiceProvider.GetService<ServiceType>: ServiceType;
begin
  GetService(TypeInfo(ServiceType), Result);
end;

procedure IServiceProvider.GetRequiredService(const ServiceType: PTypeInfo; out Service);
begin
  if not TryGet(ServiceType, Service) then
    raise Error('Cannot resolve service: %s', [ServiceType.Name]);
end;

function IServiceProvider.GetRequiredService<ServiceType>: ServiceType;
begin
  GetRequiredService(TypeInfo(ServiceType), Result);
end;

function IServiceProvider.GetServices<ServiceType>: IInterfaceList<ServiceType>;
begin
  Result := IInterfaceList<ServiceType>(GetServices(TypeInfo(ServiceType)))
end;

function IServiceProvider.GetServices(const ServiceType: PTypeInfo): IInterfaceList<IInterface>;
begin
  FImplementor.TryGetAll(ServiceType, IInterfaceList(Result));
end;

function IServiceProvider.AsType<ServiceType>: ServiceType;
begin
  var PInfo: PTypeInfo :=  TypeInfo(ServiceType);
  Supports(FImplementor, PInfo.TypeData.Guid, Result);
end;

function IServiceProvider.GetFromInterfaceOps(const ServiceType: PTypeInfo): TArray<TRttiMethod>;
begin
  var FImpl := FImplementor;
  Result :=_T.GetConverFromOps(ServiceType,  function(M: TRttiMethod): Boolean
              begin
                var FromType := M.GetParameters[0].ParamType;
                Result := (FromType.TypeKind = tkInterface) and FImpl.CanResolve(FromType.Handle);
              end);
end;

function IServiceProvider.CanResolve(const ServiceType: PTypeInfo): Boolean;
begin
  Result := FImplementor.CanResolve(ServiceType) or (GetFromInterfaceOps(ServiceType) <> nil);
end;

function IServiceProvider.CreateScope: IServiceScope;
begin
  Result :=  FImplementor.CreateScope;
end;

class operator IServiceProvider.Equal(S: IServiceProvider; P: Pointer): Boolean;
begin
  Result := Pointer(S.FImplementor) = P;
end;

class operator IServiceProvider.NotEqual(S: IServiceProvider; P: Pointer): Boolean;
begin
  Result := Pointer(S.FImplementor) <> P;
end;

{ Factory }

class function Factory.From(const ServiceType: PTypeInfo; const TImpl: TClass): TServiceFactory;
begin
  Assert(Supports(TImpl, _T.GUID(ServiceType)), TImpl.Classname + 'no supports ' + _T.NameOf(ServiceType));
  Result := function(Provider: IServiceProvider): IInterface
            begin
              var Aux := TActivatorUtilities.CreateInstance(Provider, TImpl);
              Supports(Aux, _T.GUID(ServiceType), Result);
            end;
end;

class function Factory.From(const ServiceType: PTypeInfo;  const Implementor: IInterface): TServiceFactory;
begin
  Assert(Supports(Implementor, _T.GUID(ServiceType)));
  Result := function(Provider: IServiceProvider): IInterface
            begin
              Result := Implementor;
            end;
end;

{ IServiceCollection }

class operator IServiceCollection.Implicit(const Implementor: IServiceCollectionImpl): IServiceCollection;
begin
  Result.FImplementor := Implementor;
end;

class operator IServiceCollection.Implicit(const ServiceCollection: IServiceCollection): IServiceCollectionImpl;
begin
  Result := ServiceCollection.FImplementor;
end;

function IServiceCollection.GetCount: Integer;
begin
  Result := FImplementor.GetCount;
end;

function IServiceCollection.BuildServiceProvider: IServiceProvider;
begin
  Result := FImplementor.BuildServiceProvider;
end;

function IServiceCollection.AddScoped(const ServiceType: PTypeInfo; const TImpl: TClass): IServiceCollection;
begin
  Result := AddScoped(ServiceType, Factory.From(ServiceType, Timpl));
end;

function IServiceCollection.AddSingleton(const ServiceType: PTypeInfo; const TImpl: TClass): IServiceCollection;
begin
  Result := AddSingleton(ServiceType, Factory.From(ServiceType, Timpl));
end;

function IServiceCollection.AddTransient(const ServiceType: PTypeInfo; const TImpl: TClass): IServiceCollection;
begin
  Result := AddTransient(ServiceType, Factory.From(ServiceType, Timpl));
end;

function IServiceCollection.AddSingleton(const ServiceType: PTypeInfo; const Implementor: IInterface): IServiceCollection;
begin
  Result := AddSingleton(ServiceType, Factory.From(ServiceType, Implementor));
end;

function IServiceCollection.Add(const LifeTime: TServiceLifeTime; const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection;
begin
  FImplementor.Add(ServiceType, LifeTime, Factory);
  Result := Self;
end;

function IServiceCollection.Add<ServiceType>(const LifeTime: TServiceLifeTime; const Factory: TServiceFactory<ServiceType>): IServiceCollection;
begin
  Result := Add(LifeTime, TypeInfo(ServiceType), TServiceFactory(Factory));
end;

function IServiceCollection.AddSingleton(const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection;
begin
  Result := Add(Singleton, ServiceType, Factory);
end;

function IServiceCollection.AddScoped(const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection;
begin
  Result := Add(Scoped, ServiceType, Factory);
end;

function IServiceCollection.AddScoped<ServiceType, TImpl>: IServiceCollection;
begin
  Result := AddScoped(TypeInfo(ServiceType), PTypeInfo(TypeInfo(TImpl)).TypeData.ClassType);
end;

function IServiceCollection.AddScoped<ServiceType>(const Factory: TServiceFactory<ServiceType>): IServiceCollection;
begin
  Result := Add<ServiceType>(Scoped, Factory);
end;

function IServiceCollection.AddSingleton<ServiceType>(const Factory: TServiceFactory<ServiceType>): IServiceCollection;
begin
  Result := Add<ServiceType>(Singleton, Factory);
end;

function IServiceCollection.AddSingleton<ServiceType, TImpl>: IServiceCollection;
begin
  Result := AddSingleton(TypeInfo(ServiceType), PTypeInfo(TypeInfo(TImpl)).TypeData.ClassType);
end;

function IServiceCollection.AddSingleton<ServiceType>(const Implementor: ServiceType): IServiceCollection;
begin
  Result := AddSingleton(TypeInfo(ServiceType), Implementor);
end;

function IServiceCollection.AddTransient(const ServiceType: PTypeInfo; const Factory: TServiceFactory): IServiceCollection;
begin
  Result := Add(Transient, ServiceType, Factory);
end;

function IServiceCollection.AddTransient<ServiceType>(const Factory: TServiceFactory<ServiceType>): IServiceCollection;
begin
  Result := Add<ServiceType>(Transient, Factory);
end;

function IServiceCollection.AddTransient<ServiceType, TImpl>: IServiceCollection;
begin
  Result := AddTransient(TypeInfo(ServiceType), PTypeInfo(TypeInfo(TImpl)).TypeData.ClassType);
end;

function IServiceCollection.Contains<ServiceType>: Boolean;
begin
  Result := Contains(TypeInfo(ServiceType));
end;

function IServiceCollection.Contains(const ServiceType: PTypeInfo): Boolean;
begin
  Result := FImplementor.Contains(ServiceType)
end;

{ TDuckDecorator }

constructor TDuckDecorator<T>.InternalCreate(const DecoratedType: PTypeInfo; const Decorated: T);
begin
  if Assigned(Decorated) and not HasRTTI(DecoratedType) then
    raise Exception.CreateFmt('Type %s not supports RTTI', [DecoratedType.Name]);
  inherited Create(DecoratedType, CallInterceptor);
  FDecoratedType := DecoratedType;
  FDecorated := Decorated;
end;

constructor TDuckDecorator<T>.Create(Decorated: T);
begin
  InternalCreate(TypeInfo(T), Decorated);
end;

constructor TDuckDecorator<T>.Create;
begin
  InternalCreate(TypeInfo(T), nil);
end;

destructor TDuckDecorator<T>.Destroy;
begin
  OnInvoke := nil;
  FDecorated := nil;
  inherited;
end;

procedure TDuckDecorator<T>.BeforeCall(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue);
begin

end;

procedure TDuckDecorator<T>.AfterCall(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue);
begin

end;

function TDuckDecorator<T>.CallByNameTo(const Instance: TObject; MethodName: string; const Args: TArray<TValue>; var CallResult: TValue): Boolean;
begin
  if not Assigned(Instance) then Exit(False);
  var
    RC := TRttiContext.Create;
  try
    var
    RType := RC.GetType(Instance.ClassType);
    var
    Method := RType.GetMethod(MethodName);
    Result := (Method <> nil);
    if not Result then Exit;
    // Remove original Self parameter
    var
    NewArgs := Args;
    System.Delete(NewArgs, 0, 1);
    CallResult := Method.Invoke(Instance, NewArgs);
  finally
    RC.Free;
  end;

end;

procedure TDuckDecorator<T>.CallDecorated(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue);
var
  VTable: PPVtable;
  Code: Pointer;
  ArgList: TArray<TValue>;
  CallConv: TCallConv;
begin
  if not Assigned(FDecorated) then Exit;
  var Intf: IInterface;
  if not Supports(Decorated, DecoratedType.TypeData.GUID, Intf) then Exit;
  VTable := PPVtable(Intf);
  Code := VTable^^[Method.VirtualIndex];
  ArgList := Args;
  CallConv := Method.CallingConvention;
  ArgList[0] := TValue.From(Intf);
  Intf := nil;

  if Method.ReturnType <> nil then Result := System.Rtti.Invoke(Code, ArgList, CallConv, Method.ReturnType.Handle)
  else Result := System.Rtti.Invoke(Code, ArgList, CallConv, nil);
  ArgList[0] := nil;
end;

procedure TDuckDecorator<T>.CallInterceptor(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
begin
  Result := TValue.Empty;
  BeforeCall(Method, Args, Result);

  if not CallByNameTo(Self, Method.Name, Args, Result) then
    CallDecorated(Method, Args, Result);

  AfterCall(Method, Args, Result);
end;

{ TDuckDecorator }

constructor TDuckDecorator.Create(const DecoratedType: PTypeInfo; Decorated: IInvokable);
begin
  if Assigned(Decorated) and not Supports(Decorated, DecoratedType.TypeData.GUID) then
      raise Exception.CreateFmt('Decorated argument not supports interface type %s', [DecoratedType.Name]);

  InternalCreate(DecoratedType, Decorated);
end;

{ TLazy<T> }

constructor TLazy<T>.Create(ServiceProvider: IServiceProvider; const Factory: TServiceFactory<T>);
begin
  FType := TypeInfo(T);
  inherited Create(FType, CallInterceptor);
  FServiceProvider := ServiceProvider;
  FFactory := Factory;
end;

procedure TLazy<T>.CheckDelegatedReady;
begin
  if Assigned(FDelegated) then Exit;
  FDelegated := FFactory(FServiceProvider);
end;

procedure TLazy<T>.CallDelegated(Method: TRttiMethod; const Args: TArray<TValue>; var Result: TValue);
var
  VTable: PPVtable;
  Code: Pointer;
  ArgList: TArray<TValue>;
  CallConv: TCallConv;
begin
  CheckDelegatedReady;
  if not Assigned(FDelegated) then Exit;
  var Intf: Pointer;
  if not Supports(FDelegated, FType.TypeData.GUID, Intf) then Exit;

  VTable := PPVtable(IInterface(Intf));
  Code := VTable^^[Method.VirtualIndex];
  ArgList := Args;
  CallConv := Method.CallingConvention;
  ArgList[0] := TValue.From(IInterface(Intf));

  if Method.ReturnType <> nil then Result := System.Rtti.Invoke(Code, ArgList, CallConv, Method.ReturnType.Handle)
  else Result := System.Rtti.Invoke(Code, ArgList, CallConv, nil);
end;

procedure TLazy<T>.CallInterceptor(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
begin
  Result := TValue.Empty;
  CallDelegated(Method, Args, Result);
end;

{ Lazy }

class function Lazy.From<T>(Provider: IServiceProvider; const Factory: TServiceFactory<T>): T;
begin
  var Implementor := TLazy<T>.Create(Provider, Factory);
  var FType: PTypeInfo := TypeInfo(T);
  Supports(Implementor, FType.TypeData.GUID, Result);
end;

end.
