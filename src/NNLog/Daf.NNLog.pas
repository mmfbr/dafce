unit DAF.NNLog;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.IOUtils,
  System.Generics.Collections,
  Daf.Extensions.Logging,
  Daf.Logging,
  DAF.Logging.Provider,
  Daf.NNLog.Configuration;

type
  {$M+}
  TTargetClass = class of TTarget;
  TTarget = class
  private
    FName: string;
    FLayout: string;
  protected
    function RenderEvent(Entry: TLogEntry): string;
  public
    const DefaultLayout = '${timestamp} #${pid}:${thread} [${level}] ${category} | ${message} ${exception}';
    constructor Create;virtual;
    procedure Write(const Entry: TLogEntry);virtual;abstract;
    property Layout: string read FLayout write FLayout;
    property Name: string read FName write FName;
  end;

  TLogRule = class
  private
    FName: string;
    FMinLevel: TLogLevel;
    FEnabled: Boolean;
    FIsFinal: Boolean;
    FMaxLevel: TLogLevel;
    FLevels: TArray<TLogLevel>;
    FWriteTo: TArray<TTarget>;
    function NameMatch(const Category: string): Boolean;
  public
    function Matches(const Category: string; const Level: TLogLevel): Boolean;
    procedure Log(const LogEntry: TLogEntry);
    property Name: string read FName write FName;
    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    property MaxLevel: TLogLevel read FMaxLevel write FMaxLevel;
    property Levels: TArray<TLogLevel> read FLevels write FLevels;
    property WriteTo: TArray<TTarget> read FWriteTo write FWriteTo;
    property Enabled: Boolean read FEnabled write FEnabled;
    property IsFinal: Boolean read FIsFinal write FIsFinal;
  end;
  {$M-}

  TNNLogLogger = class(TLogger)
  private
    FRules: TArray<TLogRule>;
  public
    constructor Create(const Category: string; const Rules: TArray<TLogRule>);
    procedure Log(const LogEntry: TLogEntry); override;
  end;

  TNNLogProvider = class(TInterfacedObject, ILoggerProvider)
  private
    FTargets: TArray<TTarget>;
    FRules: TArray<TLogRule>;
  public
    property Rules: TArray<TLogRule> read FRules;
    constructor Create(const Targets: TArray<TTarget>; const Rules: TArray<TLogRule>);
    destructor Destroy;override;
    function CreateLogger(const Category: string): ILogger;
  end;

implementation
uses
  DAF.NNLog.Layout;

{ TLogRule }

procedure TLogRule.Log(const LogEntry: TLogEntry);
begin
  for var Target in WriteTo do
    Target.Write(LogEntry);
end;

function TLogRule.NameMatch(const Category: string): Boolean;
begin
  if Name = '*' then Exit(True);
  Result := True;
end;

function TLogRule.Matches(const Category: string; const Level: TLogLevel): Boolean;
begin
  Result := (Level >= MinLevel) and (Level <= MaxLevel) and
    ((Length(Levels) = 0) or TArray.Contains<TLogLevel>(Levels, Level)) and
    NameMatch(Category);
end;

{ TNNLogLogger }

constructor TNNLogLogger.Create(const Category: string; const Rules: TArray<TLogRule>);
begin
  inherited Create(Category);
  FRules := Rules;
end;

procedure TNNLogLogger.Log(const LogEntry: TLogEntry);
var
  Rule: TLogRule;
begin
  for Rule in FRules do
  begin
    if Rule.Enabled and Rule.Matches(LogEntry.Category, LogEntry.Level) then
    begin
      Rule.Log(LogEntry);
      if Rule.IsFinal then
        Break;
    end;
  end;
end;

{ TNNLogProvider }

constructor TNNLogProvider.Create(const Targets: TArray<TTarget>; const Rules: TArray<TLogRule>);
begin
  inherited Create;
  FTargets := Targets;
  FRules := Rules;
end;

function TNNLogProvider.CreateLogger(const Category: string): ILogger;
begin
  Result := TNNLogLogger.Create(Category, FRules);
end;

destructor TNNLogProvider.Destroy;
begin
  for var Item in FTargets do
    Item.Free;
  for var Item in FRules do
    Item.Free;
  inherited;
end;

{ TTarget }

constructor TTarget.Create;
begin
  inherited Create;
  FLayout := DefaultLayout;
end;

function TTarget.RenderEvent(Entry: TLogEntry): string;
begin
  Result := TLogLayoutEngine.ResolveLayout(Layout, Entry);
end;

end.

