program DAF.Commons.Test;

{.$DEFINE CONSOLE_TESTRUNNER}
{.$DEFINE TEXT_TESTRUNNER}
{.$DEFINE XML_TESTRUNNER}
{$DEFINE TESTINSIGHT}
{.$DEFINE VCL_TESTRUNNER}

{$IFNDEF TESTINSIGHT}

  {$IFDEF CONSOLE_TESTRUNNER}
  {$APPTYPE CONSOLE}
  {$ENDIF}

{$ENDIF}

{$STRONGLINKTYPES ON}

{$WARN DUPLICATE_CTOR_DTOR OFF}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$IFEND }
  {$IFDEF VCL_TESTRUNNER}
  VCL.Forms,
  {$IFEND }
  {$IFDEF CONSOLE_TESTRUNNER}
  DUnitX.ConsoleWriter.Base,
  {$IFEND }
  DUnitX.TestFramework,
  DUnitX.Generics,
  DUnitX.InternalInterfaces,
  DUnitX.WeakReference,
  DUnitX.FixtureResult,
  DUnitX.RunResults,
  DUnitX.Test,
  DUnitX.TestFixture,
  DUnitX.TestResult,
  DUnitX.TestRunner,
  DUnitX.Utils,
  DUnitX.IoC,
  DUnitX.MemoryLeakMonitor.Default,
  DUnitX.DUnitCompatibility,
  {$IFDEF DELPHIMOCKS}
  Delphi.Mocks,
  {$IFEND }
  Daf.Commons.Activator.Tests in 'Daf.Commons.Activator.Tests.pas',
  Daf.Commons.CmdLn.Test in 'Daf.Commons.CmdLn.Test.pas',
  Daf.Commons.Config.Test in 'Daf.Commons.Config.Test.pas';

var
  runner: ITestRunner;
  results: IRunResults;
  {$IFDEF CONSOLE_TESTRUNNER}
  logger: ITestLogger;
  {$IFEND}
  {$IFDEF XML_TESTRUNNER}
  nunitLogger: ITestLogger;
  {$IFEND}
  {$IFDEF TEXT_TESTRUNNER}
  textLogger: ITestLogger;
  {$IFEND}
begin
  ReportMemoryLeaksOnShutdown := True;

  {$IFDEF VCL_TESTRUNNER}
  Application.Initialize;
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);
  Application.Run;
  {$IFEND}

  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  exit;
  {$IFEND}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;

    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //tell the runner how we will log things

    {$IFDEF CONSOLE_TESTRUNNER}
    //Log to the console window
    logger := TDUnitXConsoleLogger.Create(true);
    runner.AddLogger(logger);
    {$IFEND}

    {$IFDEF XML_TESTRUNNER}
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);
    {$IFEND}

    {$IFDEF TEXT_TESTRUNNER}
    textLogger := TDUnitXTextFileLogger.Create(Application.Title+'.Test');
    runner.AddLogger(textLogger);
    {$IFEND}

    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    runner.FailsOnNoAsserts := True; //When true, Assertions must be made during tests;

    //Run tests
    results := runner.Execute;

    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if (TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause) then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.

