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
  System.TypInfo;

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

procedure Dump(Title: string; const Config: IConfiguration; const Indent: string = '');
begin
  if not Title.IsEmpty then
  begin
    WriteLn('-----------------');
    WriteLn(Title);
    WriteLn('-----------------');
  end;

  for var section in Config.GetChildren do
  begin
    if Section.HasChildren then
    begin
      Writeln(Indent + section.Key + ':');
      Dump('', section, Indent + '  ');
    end
    else
      Writeln(Indent + section.Key + ' = ' + section.Value);
  end;
end;

class function TNNLogLoader.Load(const Config: IConfiguration): TNNLogConfiguration;
begin
//  Dump('NNlog config', Config);
  Result := TConfigurationBinder.Bind<TNNLogConfiguration>(Config, '', boFields);
end;

class function TNNLogLoader.BuildProvider(const Context: IHostBuilderContext; const ConfigKey: string): ILoggerProvider;
begin
  Result := BuildProvider(Context.Environment, Context.Configuration.GetSection(ConfigKey));
end;

class function TNNLogLoader.BuildProvider(const Environment: IHostEnvironment; const Config: IConfiguration): ILoggerProvider;
begin
  TLogLayoutEngine.RegisterLayoutRenderers(Environment);
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

end.

