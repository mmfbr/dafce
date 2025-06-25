unit Daf.HttpServer;

interface
uses
  System.Classes,
  System.SysUtils,
  IdHTTPWebBrokerBridge,
  Daf.Extensions.Configuration,
  Daf.Extensions.Logging,
  Daf.Extensions.HttpServer;

type
  TDafHttpServer = class(TInterfacedObject, IDafHttpServer)
  private
    FWebBrokerBridge: TIdHTTPWebBrokerBridge;
    FOnStopping: TNotifyEvent;
    FOnStarting: TNotifyEvent;
    FOnStarted: TNotifyEvent;
    FOnStopped: TNotifyEvent;
    FOnError: TNotifyEvent;
    FOnDestroy: TNotifyEvent;
    FLogger: ILogger;
    function GetPort: Word;
    procedure SetPort(const Value: Word);
    procedure SetActive(const Value: Boolean);
    function GetActive: Boolean;
    function GetOnStarting: TNotifyEvent;
    procedure SetOnStarting(const Value: TNotifyEvent);
    function GetOnStarted: TNotifyEvent;
    procedure SetOnStarted(const Value: TNotifyEvent);
    function GetOnStopping: TNotifyEvent;
    procedure SetOnStopping(const Value: TNotifyEvent);
    function GetOnStopped: TNotifyEvent;
    procedure SetOnStopped(const Value: TNotifyEvent);
    procedure ClearBindings;
    procedure TerminateThreads;
    function CanBindPort: Boolean;overload;
    function CanBindPort(const APort: Integer): Boolean; overload;
    function GetIndyVersion: string;
    function GetSessionID: string;
    function GetOnError: TNotifyEvent;
    procedure SetOnError(const Value: TNotifyEvent);
    procedure FireOnError(const E: Exception);
    function GetOnDestroy: TNotifyEvent;
    procedure SetOnDestroy(const Value: TNotifyEvent);
  public
    constructor Create(const WebModuleClass: TComponentClass; const Config: IConfiguration; const LoggerFactory: ILoggerFactory = nil);
    procedure BeforeDestruction;override;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Logger: ILogger read FLogger;
    property Version: string read GetIndyVersion;
    property SessionID: string read GetSessionID;
    property Port: Word read GetPort write SetPort;
    property Active: Boolean read GetActive;
    property OnStarting: TNotifyEvent read GetOnStarting write SetOnStarting;
    property OnStarted: TNotifyEvent read GetOnStarted write SetOnStarted;
    property OnStopping: TNotifyEvent read GetOnStopping write SetOnStopping;
    property OnStopped: TNotifyEvent read GetOnStopped write SetOnStopped;
    property OnError: TNotifyEvent read GetOnError write SetOnError;
    property OnDestroy: TNotifyEvent read GetOnDestroy write SetOnDestroy;
  end;

implementation
uses
  IPPeerServer,
  IPPeerAPI,
  Web.WebReq,
  Datasnap.DSSession;

{ TDafHttpServer }

constructor TDafHttpServer.Create(const WebModuleClass: TComponentClass; const Config: IConfiguration; const LoggerFactory: ILoggerFactory = nil);
begin
  inherited Create;
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  FWebBrokerBridge := TIdHTTPWebBrokerBridge.Create(nil);
  Port := Word.Parse(Config['Port']);
  if Assigned(LoggerFactory) then
    FLogger := LoggerFactory.CreateLogger(Self.ClassType)
  else
    FLogger := TNullLogger.Create;
end;

procedure TDafHttpServer.BeforeDestruction;
begin
  inherited;
  if Assigned(FOnDestroy) then
    FOnDestroy(Self);
  FOnDestroy := nil;
end;

destructor TDafHttpServer.Destroy;
begin
  Stop;
  WebRequestHandler.WebModuleClass := nil;
  FreeAndNil(FWebBrokerBridge);
  inherited;
end;

procedure TDafHttpServer.FireOnError(const E: Exception);
begin
  if Assigned(FOnError) then
    FOnError(E);
end;

function TDafHttpServer.GetActive: Boolean;
begin
  Result := Assigned(FWebBrokerBridge) and FWebBrokerBridge.Active;
end;

function TDafHttpServer.GetOnStarting: TNotifyEvent;
begin
  Result := FOnStarting
end;

procedure TDafHttpServer.SetOnStarting(const Value: TNotifyEvent);
begin
  FOnStarting := Value;
end;

function TDafHttpServer.GetOnDestroy: TNotifyEvent;
begin
  Result := FOnDestroy;
end;

function TDafHttpServer.GetOnError: TNotifyEvent;
begin
  Result := FOnError;
end;

function TDafHttpServer.GetOnStarted: TNotifyEvent;
begin
  Result := FOnStarted;
end;

procedure TDafHttpServer.SetOnDestroy(const Value: TNotifyEvent);
begin
  FOnDestroy := Value;
end;

procedure TDafHttpServer.SetOnError(const Value: TNotifyEvent);
begin
  FOnError := Value;
end;

procedure TDafHttpServer.SetOnStarted(const Value: TNotifyEvent);
begin
  FOnStarted := Value;
end;

function TDafHttpServer.GetOnStopped: TNotifyEvent;
begin
  Result := FOnStopped;
end;

function TDafHttpServer.GetOnStopping: TNotifyEvent;
begin
  Result := FOnStopping;
end;

procedure TDafHttpServer.SetActive(const Value: Boolean);
begin
  if Assigned(FWebBrokerBridge) then
    FWebBrokerBridge.Active := Value;
end;

procedure TDafHttpServer.SetOnStopped(const Value: TNotifyEvent);
begin
  FOnStopped := Value;
end;

procedure TDafHttpServer.SetOnStopping(const Value: TNotifyEvent);
begin
  FOnStopping := Value;
end;

function TDafHttpServer.CanBindPort: Boolean;
begin
  Result := CanBindPort(Port);
end;

function TDafHttpServer.CanBindPort(const APort: Integer): Boolean;
var
  LTestServer: IIPTestServer;
begin
  Result := True;
  try
    LTestServer := PeerFactory.CreatePeer('', IIPTestServer) as IIPTestServer;
    LTestServer.TestOpenPort(APort, nil);
  except
    Result := False;
  end;
end;

function TDafHttpServer.GetPort: Word;
begin
  if not Assigned(FWebBrokerBridge) then Exit(0);
  Result := FWebBrokerBridge.DefaultPort
end;

function TDafHttpServer.GetSessionID: string;
begin
  if not Assigned(FWebBrokerBridge) then Exit('');
  Result := FWebBrokerBridge.SessionIDCookieName;
end;

function TDafHttpServer.GetIndyVersion: string;
begin
  if not Assigned(FWebBrokerBridge) then Exit('');
  Result := FWebBrokerBridge.SessionList.Version;
end;

procedure TDafHttpServer.SetPort(const Value: Word);
begin
  if not Assigned(FWebBrokerBridge) then Exit;
  FWebBrokerBridge.DefaultPort := Value;
end;

procedure TDafHttpServer.Start;
begin
  if Active then
    Exit;

  if not CanBindPort(Port) then  begin
    FireOnError(Exception.CreateFmt('Cannot start: port %d is in use', [Port]));
    Abort;
  end;

  if Assigned(FOnStarting) then
    OnStarting(Self);
  ClearBindings;
  SetActive(True);
  if Assigned(FOnStarted) then
    OnStarted(Self);
end;

procedure TDafHttpServer.Stop;
begin
  if not Active then
    Exit;

  if Assigned(FOnStopping) then
    OnStopping(Self);

  TerminateThreads;
  SetActive(False);
  ClearBindings;
  if Assigned(FOnStopped) then
    OnStopped(Self);
end;

procedure TDafHttpServer.TerminateThreads;
begin
  if TDSSessionManager.Instance <> nil then
    TDSSessionManager.Instance.TerminateAllSessions;
end;

procedure TDafHttpServer.ClearBindings;
begin
  if not Assigned(FWebBrokerBridge) then Exit();
  FWebBrokerBridge.Bindings.Clear;
end;


end.
