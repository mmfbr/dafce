unit DAF.Extensions.Logging;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Rtti,
  System.TypInfo,
  System.Threading,
  System.RegularExpressions;

type
  {
    LogLevel	  Value	  Method	        Description
    Trace	      0	      LogTrace	      Contain the most detailed messages. These messages may contain sensitive app data. These messages are disabled by default and should not be enabled in production.
    Debug	      1	      LogDebug	      For debugging and development. Use with caution in production due to the high volume.
    Information	2	      LogInformation	Tracks the general flow of the app. May have long-term value.
    Warning	    3	      LogWarning	    For abnormal or unexpected events. Typically includes errors or conditions that don't cause the app to fail.
    Error	      4	      LogError	      For errors and exceptions that cannot be handled. These messages indicate a failure in the current operation or request, not an app-wide failure.
    Critical	  5	      LogCritical	    For failures that require immediate attention. Examples: data loss scenarios, out of disk space.
    None	      6		        N/A         Specifies that no messages should be written.
  }
{$SCOPEDENUMS ON}
  TLogLevel = (Trace, Debug, Information, Warning, Error, Critical, None);
{$SCOPEDENUMS OFF}

  TLogLevelHelper = record helper for TLogLevel
    function ToString: string;
    class function TryParse(Source: string; out Level: TLogLevel): Boolean; static;
    class function Parse(Source: string): TLogLevel; overload; static;
    class function Parse(Source: string; const Def: TLogLevel): TLogLevel; overload; static;
    class function ParseList(SourceList: string): TArray<TLogLevel>; static;
  end;

  TEventId = Integer;

  TLogState = record
  public type
    TFormatter = reference to function(State: TLogState; Ex: Exception): string;
  strict private
    FTemplate: string;
    FArgs: TArray<TValue>;
    FKeyValuePairs: TArray<TPair<string, TValue>>;
    FIsStructured: Boolean;
    procedure ExtractKeyValuePairs;
  private
    function GetFormatter: TFormatter;
    class function StructuredFormat(State: TLogState; Ex: Exception): string; static;
    class function UnstructuredFormat(State: TLogState; Ex: Exception): string; static;
    property IsStructured: Boolean read FIsStructured;
  public
    constructor Create(const Template: string; const Args: TArray<TValue> = nil);
    property Template: string read FTemplate;
    property Arguments: TArray<TValue> read FArgs;
    property KeyValuePairs: TArray < TPair < string, TValue >> read FKeyValuePairs;
    property Formatter: TFormatter read GetFormatter;
    function TryGetValue(const Key: string; out Value: TValue): Boolean;
  end;

  TLogFormatter = TLogState.TFormatter;

  TLogEntry = record
  private
    FMessage: string;
    function GetMessage: string;
  public
    Level: TLogLevel;
    Category: string;
    EventId: TEventId;
    Exception: Exception;
    Scope: string;
    State: TLogState;
    Formatter: TLogFormatter;
    property Message: string read GetMessage;
  end;

  // Safe base interface for use with `with ... do`: avoids variable shadowing and identifier leakage
  ILogScopeVoid = interface(IInvokable)
    ['{7C346BD8-863C-4605-8EFA-5659894E0ACA}']
  end;

  // Actual logging scope interface
  ILogScope = interface(ILogScopeVoid)
    ['{D3244D1B-78BD-48DD-BC65-86E132119D37}']
    function GetState: TLogState;
    function GetMessage: string;
    property State: TLogState read GetState;
    property Message: string read GetMessage;
  end;

  ILogger = interface(IInvokable)
    function BeginScope(const Msg: string; const Args: TArray<TValue>; const ScopedProc: TProc = nil): ILogScopeVoid;overload;
    function BeginScope(const Msg: string; const ScopedProc: TProc = nil): ILogScopeVoid;overload;
    procedure Log(const Entry: TLogEntry); overload;
    /// <summary>
    /// Writes a log entry.
    /// </summary>
    /// <param name="logLevel">Entry will be written on this level.</param>
    /// <param name="eventId">Id of the Entry.</param>
    /// <param name="state">The entry to be written. Can be also an object.</param>
    /// <param name="exception">The exception related to this entry.</param>
    /// <typeparam name="TState">The type of the object to be written.</typeparam>
    procedure Log(const Level: TLogLevel; const EventId: TEventId; const Ex: Exception; const Msg: string;
      const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const Msg: string; const Args: TArray<TValue> = nil); overload;

    /// <summary>
    /// Formats and writes a debug log message.
    /// </summary>
    /// <param name="logger">The <see cref="ILogger"/> to write to.</param>
    /// <param name="eventId">The event id associated with the log.</param>
    /// <param name="exception">The exception to log.</param>
    /// <param name="message">Format string of the log message in message template format. Example: <c>"User {User} logged in from {Address}"</c>.</param>
    /// <param name="args">An object array that contains zero or more objects to format.</param>
    /// <example>
    /// <code language="csharp">
    /// logger.LogDebug(0, exception, "Error while processing request from {Address}", address)
    /// </code>
    /// </example>
    procedure LogDebug(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

    /// <summary>
    /// Formats and writes a debug log message.
    /// </summary>
    /// <param name="logger">The <see cref="ILogger"/> to write to.</param>
    /// <param name="eventId">The event id associated with the log.</param>
    /// <param name="message">Format string of the log message in message template format. Example: <c>"User {User} logged in from {Address}"</c>.</param>
    /// <param name="args">An object array that contains zero or more objects to format.</param>
    /// <example>
    /// <code language="csharp">
    /// logger.LogDebug(0, "Processing request from {Address}", address)
    /// </code>
    /// </example>
    procedure LogDebug(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;

    /// <summary>
    /// Formats and writes a debug log message.
    /// </summary>
    /// <param name="logger">The <see cref="ILogger"/> to write to.</param>
    /// <param name="exception">The exception to log.</param>
    /// <param name="message">Format string of the log message in message template format. Example: <c>"User {User} logged in from {Address}"</c>.</param>
    /// <param name="args">An object array that contains zero or more objects to format.</param>
    /// <example>
    /// <code language="csharp">
    /// logger.LogDebug(exception, "Error while processing request from {Address}", address)
    /// </code>
    /// </example>
    procedure LogDebug(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

    /// <summary>
    /// Formats and writes a debug log message.
    /// </summary>
    /// <param name="logger">The <see cref="ILogger"/> to write to.</param>
    /// <param name="message">Format string of the log message in message template format. Example: <c>"User {User} logged in from {Address}"</c>.</param>
    /// <param name="args">An object array that contains zero or more objects to format.</param>
    /// <example>
    /// <code language="csharp">
    /// logger.LogDebug("Processing request from {Address}", address)
    /// </code>
    /// </example>
    procedure LogDebug(const Msg: string; const Args: TArray<TValue> = nil); overload;

    procedure LogTrace(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

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

  ILogger<T> = interface(ILogger)
    ['{BDCC3739-B5C5-4DC4-8660-1E29B630972A}']
  end;

  ILoggerFactory = interface(IInvokable)
    ['{A16DDBEF-08A9-44FF-919A-607A0FBB8B58}']
    function CreateLogger(const Category: string): ILogger; overload;
    function CreateLogger(const AClass: TClass): ILogger; overload;
    function CreateLogger(const AType: PTypeInfo): ILogger; overload;
  end;

  TNullLogger = class(TInterfacedObject, ILogger)
  private
  public
    function BeginScope(const Msg: string; const Args: TArray<TValue>; const ScopedProc: TProc = nil): ILogScopeVoid;overload;
    function BeginScope(const Msg: string; const ScopedProc: TProc = nil): ILogScopeVoid;overload;
    procedure Log(const Entry: TLogEntry); overload;
    procedure Log(const Level: TLogLevel; const EventId: TEventId; const Ex: Exception; const Msg: string;
      const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure Log(const Level: TLogLevel; const Msg: string; const Args: TArray<TValue> = nil); overload;

    procedure LogDebug(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogDebug(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogDebug(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogDebug(const Msg: string; const Args: TArray<TValue> = nil); overload;

    procedure LogTrace(const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const EventId: TEventId; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;
    procedure LogTrace(const EventId: TEventId; const Ex: Exception; const Msg: string; const Args: TArray<TValue> = nil); overload;

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


{ TLogLevelHelper }

class function TLogLevelHelper.TryParse(Source: string; out Level: TLogLevel): Boolean;
begin
  Source := Source.Trim;
  Result := True;
  for var L := Low(TLogLevel) to High(TLogLevel) do
    if SameText(GetEnumName(TypeInfo(TLogLevel), Ord(L)), Source) then
    begin
      Level := L;
      Exit;
    end;
  Result := False;
end;

class function TLogLevelHelper.Parse(Source: string): TLogLevel;
begin
  if not TryParse(Source, Result) then
    raise Exception.CreateFmt('Invalid log level: %s', [Source]);
end;

class function TLogLevelHelper.Parse(Source: string; const Def: TLogLevel): TLogLevel;
begin
  if not TryParse(Source, Result) then
    Result := Def;
end;

class function TLogLevelHelper.ParseList(SourceList: string): TArray<TLogLevel>;
begin
  SetLength(Result, 0);
  var
  Sources := SourceList.Split([',']);
  var
    Level: TLogLevel;
  for var Source in Sources do
  begin
    if TryParse(Source, Level) then
      Result := Result + [Level];
  end;
end;

function TLogLevelHelper.ToString: string;
const
  LevelNames: array [TLogLevel] of string = ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'CRIT', '');
begin
  Result := LevelNames[Self];
end;

{ TLogState }

constructor TLogState.Create(const Template: string; const Args: TArray<TValue> = nil);
begin
  FTemplate := Template;
  FArgs := Args;
  FIsStructured := FTemplate.Contains('{');
  ExtractKeyValuePairs;
end;

procedure TLogState.ExtractKeyValuePairs;
begin
  var
  Matches := TRegEx.Matches(FTemplate, '\{(\w+)\}');
  SetLength(FKeyValuePairs, Matches.Count);
  var
  I := 0;
  for var Match in Matches do
  begin
    if I <= High(FArgs) then
    begin
      FKeyValuePairs[I] := TPair<string, TValue>.Create(Match.Groups[1].Value, FArgs[I]);
      Inc(I);
    end;
  end;
end;

function TLogState.GetFormatter: TLogState.TFormatter;
begin
  if IsStructured then
    Result := TLogState.StructuredFormat
  else
    Result := TLogState.UnstructuredFormat;
end;

// Surprise: the version in Rtti, raises on values of type double
function TValueArrayToArrayOfConst(const Params: TArray<TValue>): TArray<TVarRec>;
begin
  var ConvertArgs := Params;
  for var idx := 0 to High(ConvertArgs) do
    if ConvertArgs[idx].TypeInfo^.Kind in [tkFloat] then
      ConvertArgs[idx] := ConvertArgs[idx].AsExtended;

  Result := System.Rtti.TValueArrayToArrayOfConst(ConvertArgs);
end;

class function TLogState.StructuredFormat(State: TLogState; Ex: Exception): string;
begin
  Result := State.Template;
  for var Pair in State.KeyValuePairs do
    Result := Result.Replace('{' + Pair.Key + '}', Pair.Value.ToString, [rfReplaceAll]);
  Result := Format(Result, TValueArrayToArrayOfConst(State.Arguments));
end;

class function TLogState.UnstructuredFormat(State: TLogState; Ex: Exception): string;
begin
  Result := Format(State.Template, TValueArrayToArrayOfConst(State.Arguments));
end;

function TLogState.TryGetValue(const Key: string; out Value: TValue): Boolean;
var
  Pair: TPair<string, TValue>;
begin
  for Pair in FKeyValuePairs do
    if SameText(Pair.Key, Key) then
    begin
      Value := Pair.Value;
      Exit(True);
    end;
  Result := False;
end;


{ TLogEntry }

function TLogEntry.GetMessage: string;
begin
  // build message only first time
  if FMessage.IsEmpty then
  begin
    FMessage := Formatter(State, Exception);
    FMessage := FMessage + Scope;
  end;
  Result := FMessage;
end;

{ TNullLogger }

function TNullLogger.BeginScope(const Msg: string;
  const ScopedProc: TProc): ILogScopeVoid;
begin
  Result := nil;
end;

function TNullLogger.BeginScope(const Msg: string; const Args: TArray<TValue>;
  const ScopedProc: TProc): ILogScopeVoid;
begin
  Result := nil;
end;

procedure TNullLogger.Log(const Entry: TLogEntry);
begin

end;

procedure TNullLogger.Log(const Level: TLogLevel; const EventId: TEventId;
  const Ex: Exception; const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.Log(const Level: TLogLevel; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.Log(const Level: TLogLevel; const EventId: TEventId;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.Log(const Level: TLogLevel; const Ex: Exception;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogCritical(const Ex: Exception; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogCritical(const EventId: TEventId; const Ex: Exception;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogCritical(const EventId: TEventId; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogCritical(const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogDebug(const EventId: TEventId; const Ex: Exception;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogDebug(const EventId: TEventId; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogDebug(const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogDebug(const Ex: Exception; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogError(const EventId: TEventId; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogError(const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogError(const Ex: Exception; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogError(const EventId: TEventId; const Ex: Exception;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogInformation(const Ex: Exception; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogInformation(const EventId: TEventId;
  const Ex: Exception; const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogInformation(const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogInformation(const EventId: TEventId; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogTrace(const EventId: TEventId; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogTrace(const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogTrace(const Ex: Exception; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogTrace(const EventId: TEventId; const Ex: Exception;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogWarning(const Msg: string; const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogWarning(const EventId: TEventId; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogWarning(const Ex: Exception; const Msg: string;
  const Args: TArray<TValue>);
begin

end;

procedure TNullLogger.LogWarning(const EventId: TEventId; const Ex: Exception;
  const Msg: string; const Args: TArray<TValue>);
begin

end;

end.
