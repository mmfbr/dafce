unit Daf.Commons.CmdLn.Test;

interface

uses
  System.Rtti,
  DUnitX.TestFramework,
  Daf.CmdLn.Parser;

type
  TCmdLnSpec = class
  private
    Builder: TCmdLnParserBuilder;
    Parser: ICmdLnParser;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  end;

  [TestFixture]
  CmdLinParserBuilder = class(TCmdLnSpec)
  public
    [Test]
    procedure Can_Add_Arg;
    [Test]
    procedure Can_Add_Command;
  end;

  [TestFixture]
  CmdLinParser = class(TCmdLnSpec)
  public type
    TFlavor = (fresa, nata, chocolate, lemmon);
    TItems = array[1..3] of TFlavor;
    TItemsDyn = array of TFlavor;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    [TestCase(' Used without value is true', 'verbose,--verbose,true')]
    [TestCase(' Used with value false is false', 'verbose,--verbose false,false')]
    [TestCase(' Used with value true is true', 'verbose,--verbose true,true')]
    [TestCase(' Used with value true is true', 'verbose,--verbose true,true')]
    procedure Can_parse_a_flag(const ArgName, CmdLn: string; const Expected: Boolean);

    [Test]
    [TestCase(' When arg is missing, fail', 'false,false,arg,--other')]
    [TestCase(' When value is missing, fail', 'true,false,arg,--arg')]
    [TestCase(' When value present, is ok', 'true,true,arg,--arg value')]
    procedure Can_parse_a_required_arg(const IsPresent: Boolean; const HasValue: Boolean; const ArgName, CmdLn: string);

    [Test]
    [TestCase(' an int arg, value is readed', 'number,Integer,--number 42,42')]
    [TestCase(' an float arg, float value is readed', 'arg,Double,--arg 42.24,42.24')]
    [TestCase(' an float arg, int value is readed', 'arg,Double,--arg 42,42')]
    [TestCase(' a bool arg, value is readed', 'arg,Boolean,--arg true,True')]
    [TestCase(' a str arg, value is readed', 'arg,string,--arg Hola,Hola')]
    [TestCase(' a str arg, quoted value is readed', 'arg;string;--arg "Hola, mundo";Hola, mundo',';')]
    [TestCase(' an enum arg, valid value is readed', 'arg,TVisibilityClass,--arg vcProtected,vcProtected')]
    procedure Can_parse(const ArgName, TypeName, CmdLn: string; const Expected: TValue);
    [Test]
    [TestCase(' If static and not quoted, value is readed', 'arg;TItems;--arg fresa,nata,lemmon', ';')]
    [TestCase(' If static and quoted, value is readed', 'arg;TItems;--arg "fresa, nata , lemmon"', ';')]
    [TestCase(' If dynamic and not quoted, value is readed', 'arg;TItemsDyn;--arg fresa,nata,lemmon', ';')]
    [TestCase(' If dynamic and quoted, value is readed', 'arg;TItemsDyn;--arg "fresa, nata , lemmon"', ';')]
    procedure when_parsing_array(const ArgName, TypeName, CmdLn: string);

    [Test]
    procedure can_parse_complex_line;
  end;

implementation

uses
  System.TypInfo,
  System.SysUtils;

{ TCmdLnSpec }

procedure TCmdLnSpec.Setup;
begin
  Builder := TCmdLnParserBuilder.Create;
end;

procedure TCmdLnSpec.TearDown;
begin

end;

{ CmdLinParserBuilder }

procedure CmdLinParserBuilder.Can_Add_Arg;
begin
  Builder.Arg<Boolean>('verbose');
  var
  Parser := Builder.Build;
  Assert.IsNotNull(Parser.Root['Args']['verbose']);
end;

procedure CmdLinParserBuilder.Can_Add_Command;
begin
  Builder.Command('mycmd').Arg<Boolean>('cmd_arg').EndCommand.Arg<string>('root_arg');

  var
  Parser := Builder.Build;

  Assert.IsNotNull(Parser.Root['Args']['root_arg']);
  Assert.IsNull(Parser.Root['Args']['cmd_arg']);

  Assert.IsNotNull(Parser.Root['Cmds']['mycmd']);
  Assert.IsNotNull(Parser.Root['Cmds']['mycmd']['Args']['cmd_arg']);
  Assert.IsNull(Parser.Root['Cmds']['mycmd']['Args']['root_arg']);
end;

{ CmdLinParser }

procedure CmdLinParser.Can_parse_a_flag(const ArgName, CmdLn: string; const Expected: Boolean);
begin
  Builder.Arg<Boolean>(ArgName);
  var
  Parser := Builder.Build;
  Assert.IsTrue(Parser.Root.Children.Count = 2);
  Assert.IsTrue(Parser.Root.Children[0].Children.Count = 1);
  Assert.IsTrue(Parser.Root.Children[1].Children.Count = 0);

  var
  CmdLnParams := Parser.Parse(CmdLn);

  Assert.IsTrue(CmdLnParams <> nil, 'A present argument must be parsed');
  Assert.IsTrue(CmdLnParams.Parent = nil);
  Assert.IsTrue(CmdLnParams.Key = '');
  Assert.IsTrue(CmdLnParams.Command = '');
  Assert.IsTrue(CmdLnParams.HasItem(ArgName));

  var
  Value := CmdLnParams[ArgName].ToString;
  var
    ExpectedValue: TValue := Expected;
  Assert.AreEqual(ExpectedValue.ToString, Value, 'Incorrect Value');
end;

procedure CmdLinParser.Can_parse_a_required_arg(const IsPresent: Boolean; const HasValue: Boolean; const ArgName, CmdLn: string);
begin
  Builder.Arg<string>(ArgName,
      procedure(Arg: TArgNode) begin
        Arg.Required(True)
      end
  );
  var
  Parser := Builder.Build;
  var
  CmdLnParams := Parser.Parse(CmdLn);
  if IsPresent then
  begin
    if HasValue then
     Assert.IsTrue(CmdLnParams.HasItem(ArgName), 'Required present with value, must be found')
   else
     Assert.IsFalse(CmdLnParams <> nil, 'Required  present without value, cmdln must fail parse');
  end
  else
    Assert.IsFalse(CmdLnParams <> nil, 'Required argument is missing, cmdln must fail parse');
end;

procedure CmdLinParser.Setup;
begin
  inherited;
  FormatSettings.DecimalSeparator := '.';
end;

procedure CmdLinParser.TearDown;
begin
end;

procedure CmdLinParser.Can_parse(const ArgName, TypeName, CmdLn: string; const Expected: TValue);
begin
  var RType := TRttiContext.Create.FindType('System.' + TypeName);
  Assert.IsNotNull(RType, 'Type ' + TypeName + ' not found');
  Builder.Arg(RType.Handle, ArgName);
  Parser := Builder.Build;
  var
    CmdLnParams := Parser.Parse(CmdLn);
  Assert.IsTrue(CmdLnParams <> nil);
  Assert.AreEqual(Expected.ToString, CmdLnParams[ArgName].ToString);
end;

procedure CmdLinParser.when_parsing_array(const ArgName, TypeName, CmdLn: string);
begin
  var RType := TRttiContext.Create.FindType(Self.QualifiedClassName + '.' + TypeName);
  Assert.IsNotNull(RType, 'Type ' + TypeName + ' not found');
  var
    Expected := TValue.FromArray(RType.Handle, [TValue.From<TFlavor>(fresa), TValue.From<TFlavor>(nata), TValue.From<TFlavor>(lemmon)]);
  Builder.Arg(RType.Handle, ArgName);
  Parser := Builder.Build;
  var
    CmdLnParams := Parser.Parse(CmdLn);
  Assert.IsTrue(CmdLnParams <> nil);
  Assert.AreEqual(Expected.ToString, CmdLnParams[ArgName].ToString);
end;

procedure CmdLinParser.can_parse_complex_line;
type
  TCodes = array of integer;
begin
  var
    CmdLn := '--flag build -t "template.txt" --codes 1,3,5 -i 3m,5h';

  Builder.Arg<Boolean>( 'flag|f')
  .Command('build')
    .Arg<string>('template|t')
    .Arg<TCodes>( 'codes')
    .Arg<TArray<string>>( 'intervals|i', procedure(arg: TArgNode)
      begin
        Arg.RegEx('\d+(m|h)');
      end)
  .EndCommand;

  Parser := Builder.Build;
  var
    CmdLnParams := Parser.Parse(CmdLn);
  Assert.IsTrue(CmdLnParams <> nil, 'cmdln must be parsed');
  Assert.IsTrue(CmdLnParams['flag'].AsBoolean, 'flag must be true');
  Assert.AreEqual(CmdLnParams.Command, 'build');
  Assert.AreEqual('template.txt', CmdLnParams['build.template'].AsString, 'invalide template');
  var
    Expected: TCodes := [1,3,5];
  var
    codes: TCodes := CmdLnParams['build.codes'].AsType<TCodes>;
  Assert.AreEqual(expected, codes, 'invalid codes');
end;

initialization

TDUnitX.RegisterTestFixture(CmdLinParserBuilder);
TDUnitX.RegisterTestFixture(CmdLinParser);

end.
