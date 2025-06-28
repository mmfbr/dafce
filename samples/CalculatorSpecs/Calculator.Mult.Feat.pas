unit Calculator.Mult.Feat;

interface

uses
  Calculator.Engine,
  Calculator.SpecHelpers,
  Daf.MiniSpec;

implementation

initialization

  Feature('''
  Calculator can multiply numbers

    As a user
    I need to make some multiplications
    In order to complete my tasks
  ''')
  .UseWorld<TCalculatorWorld>
  .Background
    .Given('I have a Calculator', procedure(W: TCalculatorWorld)
    begin
      W.Calculator := TCalculator.Create;
    end)

  .ScenarioOutline('<A> * <B> should be <Result>')
  .Given('the numbers <A> and <B>')
  .When('they are multiplied', procedure(W: TCalculatorWorld)
    begin
      with W do
        Calculator.Mult(A, B);
    end)
  .&Then('the result is <Result>', procedure(W: TCalculatorWorld)
    begin
      with W do
        Expect(Calculator.Result).ToEqual(Result);
    end)
  .Examples(
      [['A', 'B', 'Result'],
      [1, 1, 1],
      [10, 20, 200],
      [5, -3, -15],
      [3, 0, 0]]
    );
end.
