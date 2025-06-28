unit Mastermind.SpecHelpers;

interface
uses
  System.Rtti,
  Mastermind.Game;

type
  TGameWorld = class
  public
    Game: TMasterMind;
    Codigo: TMasterMindCode;
    Jugada: TMasterMindCode;
    GameOver: Boolean;
    Correctos: Byte;
    Desplazados: Byte;
    destructor Destroy;override;
  end;

// convierte a TValue para poder usarlo en Examples
function v(const Params: TMasterMindCode): TValue;
implementation

function V(const Params: TMasterMindCode): TValue;
begin
  Result := TValue.From(Params);
end;

{ TGameWorld }

destructor TGameWorld.Destroy;
begin
  Game.Free;
  inherited
end;

end.
