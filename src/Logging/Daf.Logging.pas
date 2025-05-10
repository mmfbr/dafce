unit Daf.Logging;

interface
uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Daf.Extensions.Logging;

type
  TLogScopes = class
  private
    FLock: TObject;
    FScopes: TStack<ILogScope>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Lock; inline;
    procedure Unlock; inline;
    procedure WithLock(Proc: TProc);
    procedure Pop(const Scope: ILogScope);
    procedure Push(const Scope: ILogScope);
    function ToArray: TArray<ILogScope>;
  end;

  TLogScopeObject = class(TInterfacedObject, ILogScope, ILogScopeVoid)
  private
    FLogScopes: TLogScopes;
    FDisposed: Boolean;
    FMessage: string;
    FState: TLogState;
  public
    function GetState: TLogState;
    function GetMessage: string;
    function _Release: Integer; stdcall;
    constructor Create(const LogScopes: TLogScopes; const State: TLogState);
    property State: TLogState read GetState;
    property Message: string read GetMessage;
  end;

  TLogger = class(TInterfacedObject, ILogger)
  private
    FCategory: string;
    FScopes: TLogScopes;
    function GetScopeMessage: string;
  public
    constructor Create(const ACategory: string);
    destructor Destroy; override;
    procedure Log(const Entry: TLogEntry); overload; virtual; abstract;

    function BeginScope(const Msg: string; const Args: TArray<TValue>; const ScopedProc: TProc = nil): ILogScopeVoid;overload;
    function BeginScope(const Msg: string; const ScopedProc: TProc = nil): ILogScopeVoid;overload;
    procedure Log(const Level: TLogLevel; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const EventId: TEventId; const Ex: Exception; const Msg: string;
      const Args: TArray<TValue> = nil); overload;

    procedure LogTrace(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

    procedure LogDebug(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogDebug(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogDebug(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogDebug(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

    procedure LogInformation(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogInformation(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogInformation(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogInformation(const EventId: TEventId; const Ex: Exception; const Msg: string;
      const Args: TArray<TValue> = nil); overload;

    procedure LogWarning(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogWarning(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogWarning(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogWarning(const EventId: TEventId; const Ex: Exception; const Msg: string;
      const Args: TArray<TValue> = nil); overload;

    procedure LogError(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogError(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogError(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogError(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

    procedure LogCritical(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogCritical(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogCritical(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogCritical(const EventId: TEventId; const Ex: Exception; const Msg: string;
      const Args: TArray<TValue> = nil); overload;
  end;

implementation

  { TLogScopeObject }

constructor TLogScopeObject.Create(const LogScopes: TLogScopes; const State: TLogState);
begin
  inherited Create;
  FLogScopes := LogScopes;
  FState := State;
end;

function TLogScopeObject.GetMessage: string;
begin
  // build message only first time
  if FMessage.IsEmpty then
    FMessage := FState.Formatter(FState, nil);
  Result := FMessage;
end;

function TLogScopeObject.GetState: TLogState;
begin
  Result := FState;
end;

function TLogScopeObject._Release: Integer;
begin
  FLogScopes.WithLock(
    procedure
    begin
      var
      Aux := inherited;
      if (Aux = 1) and not FDisposed then
      begin
        FDisposed := True;
        FLogScopes.Pop(Self);
      end;
    end);
  Result := RefCount;
end;


{ TLogScopes }

constructor TLogScopes.Create;
begin
  inherited;
  FLock := TObject.Create;
  FScopes := TStack<ILogScope>.Create;
end;

destructor TLogScopes.Destroy;
begin
  FScopes.Free;
  FLock.Free;
  inherited;
end;

procedure TLogScopes.WithLock(Proc: TProc);
begin
  Lock;
  try
    Proc;
  finally
    Unlock;
  end;
end;

procedure TLogScopes.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TLogScopes.Unlock;
begin
  TMonitor.Exit(FLock);
end;

procedure TLogScopes.Push(const Scope: ILogScope);
begin
  WithLock(
    procedure
    begin
      FScopes.Push(Scope);
    end);
end;

procedure TLogScopes.Pop(const Scope: ILogScope);
begin
  WithLock(
    procedure
    begin
      Assert(FScopes.Peek = Scope, 'Unbalanced log scope. Check use of ''with .. do''');
      FScopes.Pop;
    end);
end;

function TLogScopes.ToArray: TArray<ILogScope>;
begin
  var
    Aux: TArray<ILogScope>;
  WithLock(
    procedure
    begin
      Aux := FScopes.ToArray;
    end);
  Result := Aux;
end;

{ TLogger }

constructor TLogger.Create(const ACategory: string);
begin
  inherited Create;
  FCategory := ACategory;
  FScopes := TLogScopes.Create;
end;

destructor TLogger.Destroy;
begin
  FScopes.Free;
end;

function TLogger.BeginScope(const Msg: string; const ScopedProc: TProc): ILogScopeVoid;
begin
  Result := BeginScope(Msg, nil, ScopedProc);
end;

function TLogger.BeginScope(const Msg: string; const Args: TArray<TValue>; const ScopedProc: TProc = nil): ILogScopeVoid;
begin
  var
    Scope: ILogScope;
  FScopes.WithLock(
    procedure
    begin
      Scope := TLogScopeObject.Create(FScopes, TLogState.Create(Msg, Args));
      FScopes.Push(Scope);
    end);

  if Assigned(ScopedProc) then
  begin
    Result := nil;
    ScopedProc;
    Scope := nil;
  end
  else
    Result := Scope;
end;

procedure TLogger.LogTrace(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Trace, EventId, Ex, Msg, Args);
end;

procedure TLogger.LogTrace(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Trace, Ex, Msg, Args);
end;

procedure TLogger.LogTrace(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Trace, EventId, Msg, Args);
end;

procedure TLogger.LogTrace(const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Trace, Msg, Args);
end;

procedure TLogger.LogDebug(const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Debug, Msg, Args);
end;

procedure TLogger.LogDebug(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Debug, EventId, Msg, Args);
end;

procedure TLogger.LogDebug(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Debug, Ex, Msg, Args);
end;

procedure TLogger.LogDebug(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Debug, EventId, Ex, Msg, Args);
end;

procedure TLogger.LogInformation(const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Information, Msg, Args);
end;

procedure TLogger.LogInformation(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Information, EventId, Msg, Args);
end;

procedure TLogger.LogInformation(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Information, Ex, Msg, Args);
end;

procedure TLogger.LogInformation(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Information, EventId, Ex, Msg, Args);
end;

procedure TLogger.LogWarning(const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Warning, Msg, Args);
end;

procedure TLogger.LogWarning(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Warning, EventId, Msg, Args);
end;

procedure TLogger.LogWarning(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Warning, Ex, Msg, Args);
end;

procedure TLogger.LogWarning(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Warning, EventId, Ex, Msg, Args);
end;

procedure TLogger.LogError(const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Error, Msg, Args);
end;

procedure TLogger.LogError(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Error, EventId, Msg, Args);
end;

procedure TLogger.LogError(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Error, Ex, Msg, Args);
end;

procedure TLogger.LogError(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Error, EventId, Ex, Msg, Args);
end;

procedure TLogger.LogCritical(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Critical, EventId, Ex, Msg, Args);
end;

procedure TLogger.LogCritical(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Critical, Ex, Msg, Args);
end;

procedure TLogger.LogCritical(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Critical, EventId, Msg, Args);
end;

procedure TLogger.LogCritical(const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(TLogLevel.Critical, Msg, Args);
end;

procedure TLogger.Log(const Level: TLogLevel; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(Level, 0, Msg, Args);
end;

procedure TLogger.Log(const Level: TLogLevel; const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(Level, EventId, nil, Msg, Args);
end;

procedure TLogger.Log(const Level: TLogLevel; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil);
begin
  Log(Level, 0, Ex, Msg, Args);
end;

function TLogger.GetScopeMessage: string;
begin
  var
  Scopes := FScopes.ToArray;
  var
    Messages: TArray<string>;
  SetLength(Messages, Length(Scopes));
  for var idx := 0 to High(Scopes) do
    Messages[High(Scopes) - idx] := Scopes[idx].Message;
  Result := string.Join(' | ', Messages);
  if not Result.IsEmpty then
    Result := ' | ' + Result;
end;

procedure TLogger.Log(const Level: TLogLevel; const EventId: TEventId; const Ex: Exception; const Msg: string;
const Args: TArray<TValue> = nil);
begin
  var
  State := TLogState.Create(Msg, Args);
  var
    Entry: TLogEntry;
  Entry.Scope := GetScopeMessage;
  Entry.Level := Level;
  Entry.Category := FCategory;
  Entry.EventId := EventId;
  Entry.Exception := Ex;
  Entry.State := State;
  Entry.Formatter := Entry.State.Formatter;
  Log(Entry);
end;

end.
