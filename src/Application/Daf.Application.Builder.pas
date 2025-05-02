unit DAF.Application.Builder;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Daf.Extensions.Hosting,
  Daf.Extensions.DependencyInjection,
  Daf.Extensions.Configuration,
  Daf.Hosting,
  Daf.Application.Version,
  Daf.AppModule.DependencyInjection;

type
  IDafApplication = interface(IInvokable)
    ['{FAE0176F-FED1-42DF-92DF-C2A219853AC4}']
    function GetVersionInfo: TVersionInfo;
    function GetEnvironment: IHostEnvironment;
    function GetHost: IHost;
    function GetServices: IServiceProvider;
    procedure Start;
    procedure Stop;
    procedure WaitForShutdown;
    procedure Run(const WaitForShutdown: Boolean = False);overload;
    procedure Run(const Exec: TProc<IServiceProvider>; const WaitForShutdown: Boolean = False);overload;
    //Actually only for syntactic compatibility
    procedure RunAsync(const Exec: TProc<IServiceProvider> = nil; const WaitForShutdown: Boolean = False);
    function GetConfiguration: IConfiguration;
    property VersionInfo: TVersionInfo read GetVersionInfo;
    property Host: IHost read GetHost;
    property Environment: IHostEnvironment read GetEnvironment;
    property Configuration: IConfiguration read GetConfiguration;
    property Services: IServiceProvider read GetServices;
  end;

  TDafApplication = class;
  TDafApplicationClass = class of TDafApplication;
  TDafApplicationBuilderClass = class of TDafApplicationBuilder;
  TDafApplicationBuilder = class(THostBuilder)
  strict private
    FAppClass: TDafApplicationClass;
  private
  protected
    procedure DoConfigureServices(Context: IHostBuilderContext; Services: IServiceCollection);override;
  public
    function AppClass: TDafApplicationClass;inline;
    constructor Create(const AppClass: TDafApplicationClass);
    function Build: IDafApplication;
  end;

  {$M+}
  TDafApplication = class(TInterfacedObject, IDafApplication)
  strict private
    FVersionInfo: TVersionInfo;
    FHost: IHost;
    FEnvironment: IHostEnvironment;
    FConfiguration: IConfiguration;
  private
    class var FApp: TDafApplication;
    function GetEnvironment: IHostEnvironment;
    function GetServices: IServiceProvider;
    function GetVersionInfo: TVersionInfo;
    function GetHost: IHost;
    function GetConfiguration: IConfiguration;
  protected
    class function CreateBuilder(BuilderClass: TDafApplicationBuilderClass): TDafApplicationBuilder;overload;
    function VersionRequested: Boolean;virtual;
    procedure Execute;virtual;
  public
    class function CreateBuilder: TDafApplicationBuilder;overload;
    class function CreateBuilder<T: TDafApplicationBuilder>: T;overload;
    class function App: TDafApplication;inline;
    constructor Create(const Host: IHost);virtual;
    procedure Start;
    procedure Stop;
    procedure WaitForShutdown;
    procedure Run(const WaitForShutdown: Boolean = False);overload;
    procedure Run(const Exec: TProc<IServiceProvider>; const WaitForShutdown: Boolean = False);overload;
    //Actually only for syntactic compatibility
    procedure RunAsync(const Exec: TProc<IServiceProvider> = nil; const WaitForShutdown: Boolean = False);
    property VersionInfo: TVersionInfo read GetVersionInfo;
    property Host: IHost read GetHost;
    property Environment: IHostEnvironment read GetEnvironment;
    property Configuration: IConfiguration read GetConfiguration;
    property Services: IServiceProvider read GetServices;
  end;
  {$M-}

implementation
uses
  Daf.Rtti,
  Daf.DependencyInjection;


{ TDafApplicationBuilder }

constructor TDafApplicationBuilder.Create(const AppClass: TDafApplicationClass);
begin
  inherited Create;
  FAppClass := AppClass;
end;


procedure TDafApplicationBuilder.DoConfigureServices(Context: IHostBuilderContext; Services: IServiceCollection);
begin
  inherited;
  AppModules.Add(Services, _T.PackageOf(FAppClass));
end;

function TDafApplicationBuilder.AppClass: TDafApplicationClass;
begin
  Result := FAppClass;
end;

function TDafApplicationBuilder.Build: IDafApplication;
begin
  var Host := inherited Build;
  Result := FAppClass.Create(Host);
end;

{ TDafApplication }

class function TDafApplication.CreateBuilder(BuilderClass: TDafApplicationBuilderClass): TDafApplicationBuilder;
begin
  Result := BuilderClass.Create(Self);
end;

class function TDafApplication.CreateBuilder: TDafApplicationBuilder;
begin
  Result := CreateBuilder(TDafApplicationBuilder);
end;

class function TDafApplication.CreateBuilder<T>: T;
begin
  Result := CreateBuilder(T) as T;
end;

constructor TDafApplication.Create(const Host: IHost);
begin
  FApp := Self;
  inherited Create;
  FVersionInfo := TVersionInfo.GetFrom(Self.ClassType);
  FHost := Host;
  FEnvironment := Services.GetRequiredService<IHostEnvironment>;
  FConfiguration := Services.GetRequiredService<IConfiguration>;
end;

function TDafApplication.VersionRequested: Boolean;
begin
  Result := (ParamCount > 0) and (ParamStr(1) = '--version');
end;

procedure TDafApplication.Run(const WaitForShutdown: Boolean = False);
begin
  RunAsync(nil, WaitForShutdown);
end;

procedure TDafApplication.Run(const Exec: TProc<IServiceProvider>; const WaitForShutdown: Boolean = False);
begin
  RunAsync(Exec, WaitForShutdown);
end;

procedure TDafApplication.RunAsync(const Exec: TProc<IServiceProvider> = nil; const WaitForShutdown: Boolean = False);
begin
  Start;
  try
    if Assigned(Exec) then
      Exec(Services)
    else
      Execute;
  except
    Stop;
    raise;
  end;

  if WaitForShutdown then
    Host.WaitForShutdown;
  Stop;
end;

procedure TDafApplication.Execute;
begin

end;

procedure TDafApplication.Start;
begin
  Host.Start;
end;

procedure TDafApplication.Stop;
begin
  Host.Stop;
  FHost := nil;
end;

procedure TDafApplication.WaitForShutdown;
begin
  Host.WaitForShutdown;
end;

function TDafApplication.GetVersionInfo: TVersionInfo;
begin
  Result := FVersionInfo;
end;

class function TDafApplication.App: TDafApplication;
begin
  Result := FApp;
end;

function TDafApplication.GetHost: IHost;
begin
  Result := FHost;
end;

function TDafApplication.GetConfiguration: IConfiguration;
begin
  Result := FConfiguration;
end;

function TDafApplication.GetEnvironment: IHostEnvironment;
begin
  Result := FEnvironment;
end;

function TDafApplication.GetServices: IServiceProvider;
begin
  Result := FHost.Services;
end;

end.

