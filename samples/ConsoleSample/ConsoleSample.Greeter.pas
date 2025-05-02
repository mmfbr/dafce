unit ConsoleSample.Greeter;

interface

type
  // los servicios inyectados deben tener GUID (para identifcar su tipo) y RTTI
  // Para que tengan RTTI, basta extender IInvokable, o activarla en el tipo
  // con la directiva $M+ / $M-.
  IGreeter = interface(IInvokable)
    ['{10B734DC-FADF-4E31-9DE4-76E3BFC27D1D}']
    procedure Greet;
  end;

  TGreeter = class(TInterfacedObject, IGreeter)
  private
    FTitle: string;
    FVersion: string;
    FMessage: string;
  public
    // Como alternativa se puede requerir directamente IConfiguration
    constructor Create(const ATitle, AVersion, AMessage: string);
    procedure Greet;
  end;

implementation

uses
  System.SysUtils;

{ TGreeter }

constructor TGreeter.Create(const ATitle, AVersion, AMessage: string);
begin
  FTitle := ATitle;
  FVersion := AVersion;
  FMessage := AMessage;
end;

procedure TGreeter.Greet;
begin
  Writeln(StringOfChar('=', 30));
  Writeln(Format('  %s v%s', [FTitle, FVersion]));
  Writeln(StringOfChar('=', 30));
  Writeln(FMessage);
end;

end.