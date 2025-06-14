unit Calculator.Engine;

interface

type
  TCalculator = class
  strict private
    FResult: Integer;
  public
    procedure Add(A, B: Integer);
    procedure Mult(A, B: Integer);
    property Result: Integer read FResult;
  end;

implementation

procedure TCalculator.Add(A, B: Integer);
begin
  FResult := A + B;
end;

procedure TCalculator.Mult(A, B: Integer);
begin
  FResult := A * B;
end;

end.
