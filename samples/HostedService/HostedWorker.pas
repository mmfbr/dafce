unit HostedWorker;

interface

uses
  System.SysUtils, System.DateUtils, System.Threading,
  Daf.Extensions.Hosting,
  Daf.Extensions.Logging,
  Daf.Threading;

type
  THostedWorker = class(TInterfacedObject, IHostedService)
  private
    FLifetime: IHostApplicationLifetime;
    FLogger: ILogger;
    FCancellation: ICancellationTokenSource;
    FTask, FContinuation: ITask;
    procedure DoWork(const Token: ICancellationToken);
    procedure HandleException(E: Exception);
  protected
  public
    constructor Create(const LoggerFactory: ILoggerFactory; const Lifetime: IHostApplicationLifetime);
    procedure Start;
    procedure Stop;
    property Logger: ILogger read FLogger;
    property Lifetime: IHostApplicationLifetime read FLifetime;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs;

{ THostedWorker }

constructor THostedWorker.Create(const LoggerFactory: ILoggerFactory; const Lifetime: IHostApplicationLifetime);
begin
  inherited Create;
  FLogger := LoggerFactory.CreateLogger(Self.ClassInfo);
  FLifetime := Lifetime;
  FCancellation := CreateCancellationTokenSource;
  FLifetime.RegisterOnStopping(
    procedure
    begin
      FLogger.LogWarning('🚪 El host se está apagando, THostedWorker preparando su salida...');
    end);
end;

procedure THostedWorker.DoWork(const Token: ICancellationToken);
begin
  var
  Idx := 0;
  with FLogger.BeginScope('working with guid {guid}', [TGUID.NewGuid.ToString]) do
  begin
    while not FCancellation.IsCancellationRequested and (Token.WaitFor(1000) = wrTimeout) do
    begin
      Inc(Idx);

      // Here 'with ... do' don't works properly, because the the LogScope is release too late (after next BeginScope)
      FLogger.BeginScope('scope {number}', [Idx],
        procedure
        begin
          FLogger.LogInformation('I''m working at [%s] ...', [FormatDateTime('hh:nn:ss', Now)]);
          case Random(9) of
            0:
              raise Exception.Create('Simulated Error in ' + ClassName);
            1:
              FCancellation.Cancel;
          end;
        end);
    end;
  end;
end;

procedure THostedWorker.HandleException(E: Exception);
begin
  FLogger.LogError(E, 'TTimeWorker raised!');
end;

procedure THostedWorker.Start;
begin
  with FLogger.BeginScope('probando scope') do
  begin
    // The LogScope is released right after this message because the rest is executed in another thread, so this method
    // actually ends here
    FLogger.LogInformation('🟢 THostedWorker.Start called');

    FTask := TTask.Run(
      procedure
      begin
        FLogger.BeginScope('probando scope 2');
        try
          DoWork(FCancellation.Token);
        except
          on E: Exception do
          begin
            FCancellation.Cancel;
            raise;
          end;
        end;
      end);

    FContinuation := TTask.Run(
      procedure
      begin
        try
          FTask.Wait;
        except
          on E: EAggregateException do
          begin
            HandleException(E.InnerExceptions[0]);
            Exit;
          end;
          on E: Exception do
          begin
            HandleException(E);
            Exit;
          end;
        end;
        case FTask.Status of
          TTaskStatus.Completed:
            FLogger.LogInformation('✅ Servicio finalizó correctamente');
          TTaskStatus.Exception:
            FLogger.LogError('💥 Servicio falló inesperadamente');
          TTaskStatus.Canceled:
            FLogger.LogWarning('⚠️ Servicio cancelado');
        end;
      end);
  end;
end;

procedure THostedWorker.Stop;
begin
  FLogger.LogInformation('🔴 THostedWorker.Stop called');
  FCancellation.Cancel;

  if Assigned(FTask) and not(FTask.Status in [TTaskStatus.Completed, TTaskStatus.Canceled, TTaskStatus.Exception]) then
    try
      FLogger.LogInformation('✅ Esperando terminacion del servicio');
      FTask.Wait;
    except
      on E: Exception do
        FLogger.LogError(E, '❗ Error supervisando el servicio');
    end;

  if Assigned(FContinuation) and not(FContinuation.Status in [TTaskStatus.Completed, TTaskStatus.Canceled, TTaskStatus.Exception])
  then
  begin
    try
      Logger.LogInformation('✅ Esperando terminacion del finalizador');
      FContinuation.Wait;
    except
      on E: Exception do
        Logger.LogError(E, '❗ Error esperando al finalizador');
    end;
  end;
end;

end.
