unit DAF.NNLog.Loader;

interface

uses
  Daf.Extensions.Hosting,
  Daf.Extensions.Logging,
  DAF.Logging.Provider,
  DAF.NNLog,
  DAF.NNLog.Layout,
  DAF.NNLog.Configuration,
  DAF.Extensions.Configuration,
  DAF.Configuration.Binder,
  System.Generics.Collections;

type
  TNNLogLoader = class
  private
    class procedure RegisterLayoutRenderers(const Environment: IHostEnvironment);
    class function BuildRule(const TargetMap: TDictionary<string, TTarget>; const RuleCfg: TLogRuleConfig): TLogRule; static;
    class function BuildTarget(const TargetCfg: TTargetConfig): TTarget; static;
    class function ParseWriteTo(const TargetMap: TDictionary<string, TTarget>; const WriteTo: string): TArray<TTarget>; static;
  public
    class function Load(const Config: IConfiguration): TNNLogConfiguration;
    class function BuildProvider(const Context: IHostBuilderContext; const ConfigKey: string): ILoggerProvider;overload;
    class function BuildProvider(const Environment: IHostEnvironment; const Config: IConfiguration): ILoggerProvider;overload;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Daf.Types;

{ TNNLogLoader }

class function TNNLogLoader.BuildTarget(const TargetCfg: TTargetConfig): TTarget;
begin

  var TargetType := TargetCfg.TargetType;
  var RttiContext := TRttiContext.Create;

  // Naming convenion: Targets live in DAF.NNLog.Targets.<TargetType>
  // The class must be named T<TargetType>Target;
  // WARINING: FindType is Case Sensitive !!
  var FullTargetClassName := Format('DAF.NNLog.Targets.%s.T%sTarget', [TargetType, TargetType]);
  if TargetType = 'File' then //is reserved word and cannot follow the convenion
    FullTargetClassName := Format('DAF.NNLog.Targets.%s_.T%sTarget', [TargetType, TargetType]);

  var RttiType := RttiContext.FindType(FullTargetClassName);

  if not Assigned(RttiType) then
    raise Exception.CreateFmt('DAF.NNLog Error: Unknown target type %s', [TargetType]);

  var TargetClass := TTargetClass(RttiType.AsInstance.MetaclassType);

  if  not TargetClass.InheritsFrom(TTarget) then
    raise Exception.CreateFmt('DAF.NNLog Error: Invalid target type %s', [TargetType]);

  Result := TargetClass.Create as TTarget;
  Result.Name := TargetCfg.Name;
  for var Key in TargetCfg.Keys do
  begin
    var Prop := RttiType.GetProperty(Key);
    if Assigned(Prop) and Prop.IsWritable then
      Prop.SetValue(Result, ConvertTo(TargetCfg[Key], Prop.DataType.Handle));
  end;
end;

class function TNNLogLoader.ParseWriteTo(const TargetMap: TDictionary<string, TTarget>; const WriteTo: string): TArray<TTarget>;
begin
  var Names := WriteTo.Split([',']);
  SetLength(Result, 0);
  for var Name in Names do
  begin
    if TargetMap.ContainsKey(Name) then
      Result := Result + [TargetMap[Name]]
  end;
end;

class function TNNLogLoader.BuildRule(const TargetMap: TDictionary<string, TTarget>; const RuleCfg: TLogRuleConfig): TLogRule;
begin
  Result := TLogRule.Create;
  Result.Name := RuleCfg.Name;
  Result.Enabled := RuleCfg.Enabled;
  Result.MinLevel := TLogLevel.Parse(RuleCfg.MinLevel, Low(TLogLEvel));
  Result.Levels :=  TLogLevel.ParseList(RuleCfg.Levels);
  Result.MaxLevel := TLogLevel.Parse(RuleCfg.MaxLevel, Pred(High(TLogLevel)));
  Result.WriteTo :=  ParseWriteTo(TargetMap, RuleCfg.WriteTo);
  Result.IsFinal := RuleCfg.IsFinal;
end;

class function TNNLogLoader.Load(const Config: IConfiguration): TNNLogConfiguration;
begin
  Result := TConfigurationBinder.Bind<TNNLogConfiguration>(Config, '', boFields);
end;

class function TNNLogLoader.BuildProvider(const Context: IHostBuilderContext; const ConfigKey: string): ILoggerProvider;
begin
  Result := BuildProvider(Context.Environment, Context.Configuration.GetSection(ConfigKey));
end;

class function TNNLogLoader.BuildProvider(const Environment: IHostEnvironment; const Config: IConfiguration): ILoggerProvider;
begin
  RegisterLayoutRenderers(Environment);
  var Rules: TArray<TLogRule>;
  var NLogConfig := Load(Config);
  try
    var TargetMap := TDictionary<string, TTarget>.Create;
    try
      for var TgtCfg in NLogConfig.Targets do
        TargetMap.Add(TgtCfg.Key, BuildTarget(TgtCfg.Value));

      SetLength(Rules, Length(NLogConfig.Rules));
      var idx := 0;
      for var RuleCfg in NLogConfig.Rules do
      begin
        Rules[idx] := BuildRule(TargetMap, RuleCfg);
        Inc(idx);
      end;
      Result := TNNLogProvider.Create(TargetMap.Values.ToArray, Rules);
    finally
      TargetMap.Free;
    end;
  finally
    NLogConfig.Free;
  end;
end;

class procedure TNNLogLoader.RegisterLayoutRenderers(const Environment: IHostEnvironment);
begin
  TLogLayoutEngine.RegisterRenderer('environment',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := Environment.EnvironmentName;
    end);

  TLogLayoutEngine.RegisterRenderer('contentRootPath',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := Environment.ContentRootPath;
    end);

  TLogLayoutEngine.RegisterRenderer('ApplicationName',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := Environment.ApplicationName;
    end);

  TLogLayoutEngine.RegisterRenderer('binPath',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := IncludeTrailingPathDelimiter(TPath.GetDirectoryName(ParamStr(0)));
      //Result := Environment.BinPath;
    end);
  TLogLayoutEngine.RegisterRenderer('exception',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      if not Assigned(Entry.Exception) then
        Exit('');

      if Arg.ToLower = 'stacktrace' then
        Result := Entry.Exception.StackTrace
      else
        Result := Entry.Exception.ClassName + ': ' + Entry.Exception.Message;
    end);
  TLogLayoutEngine.RegisterRenderer('level',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := Entry.Level.ToString;
    end);

  TLogLayoutEngine.RegisterRenderer('category',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := Entry.Category;
    end);

  TLogLayoutEngine.RegisterRenderer('message',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := Entry.Message;
    end);

  TLogLayoutEngine.RegisterRenderer('env',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := GetEnvironmentVariable(Arg);
    end);

  TLogLayoutEngine.RegisterRenderer('event-properties',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      var Value: TValue;
      if Entry.State.TryGetValue(Arg, Value) then
        Result := Value.ToString()
      else
        Result := '';
    end);

  TLogLayoutEngine.RegisterRenderer('date',
    function(const Arg: string; const Entry: TLogEntry): string
    var
      FormatStr: string;
    begin
      FormatStr := Arg;
      if FormatStr.IsEmpty then
        FormatStr := 'yyyy-MM-dd';
      Result := FormatDateTime(FormatStr, Now);
    end);

  TLogLayoutEngine.RegisterRenderer('timestamp',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := FormatDateTime('yyyy-MM-dd HH:mm:ss.zzz', Now);
    end);

  TLogLayoutEngine.RegisterRenderer('thread',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := IntToStr(TThread.Current.ThreadID);
    end);

  TLogLayoutEngine.RegisterRenderer('pid',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := IntToStr(Debugger.CurrentProcessId);
    end);

  TLogLayoutEngine.RegisterRenderer('newline',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := sLineBreak;
    end);

  TLogLayoutEngine.RegisterRenderer('uppercase',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := UpperCase(Arg);
    end);

  TLogLayoutEngine.RegisterRenderer('lowercase',
    function(const Arg: string; const Entry: TLogEntry): string
    begin
      Result := LowerCase(Arg);
    end);

end;

end.

