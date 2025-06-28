unit Calculator.Add.Feat;

interface
implementation
uses
  Calculator.Engine,
  Calculator.SpecHelpers,
  Daf.MiniSpec;

initialization

  Feature('''
  Calculator can add numbers

    As a user
    I need to make some sums
    In order to complete my tasks
  ''')
  .UseWorld<TCalculatorWorld>
  .Background
    .Given('I have a calculator', procedure(W: TCalculatorWorld)
    begin
      W.Calculator := TCalculator.Create;
    end)
  .Scenario('Adding two numbers')
  .Given('the numbers 2 and 3', procedure(W: TCalculatorWorld)
    begin
      W.A := 2;
      W.B := 3;
    end)
  .When('they are added', procedure(W: TCalculatorWorld)
    begin
      with W do
        Calculator.Add(A, B);
    end)
  .&Then('the result is 5', procedure(W: TCalculatorWorld)
    begin
      Expect(W.Calculator.Result).ToEqual(5);
    end)
  .ScenarioOutline('Adding <A> and <B> should be <Result>')
  .Given('the numbers <A> and <B>')
  .When('they are added', procedure(W: TCalculatorWorld)
    begin
      W.Calculator.Add(W.A, W.B);
    end)
  .&Then('the result is <Result>', procedure(W: TCalculatorWorld)
    begin
      Expect(W.Calculator.Result).ToEqual(W.Result);
    end)
  .Examples(
      [['A', 'B', 'Result'],
      [1, 1, 2],
      [10, 20, 30],
      [5, -2, 4],
      [0, 0, 0]]
    );
end.
