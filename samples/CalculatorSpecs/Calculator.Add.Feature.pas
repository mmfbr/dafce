unit Calculator.Add.Feature;

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
    .Given('I have a calculator', procedure(World: TCalculatorWorld)
    begin
      World.Calculator := TCalculator.Create;
    end)
  .Scenario('Adding two numbers')
  .Given('the numbers 2 and 3', procedure(World: TCalculatorWorld)
    begin
      World.A := 2;
      World.B := 3;
    end)
  .When('they are added', procedure(World: TCalculatorWorld)
    begin
      with World do
        Calculator.Add(A, B);
    end)
  .&Then('the result is 5', procedure(World: TCalculatorWorld)
    begin
      Expect(World.Calculator.Result).ToEqual(5);
    end)
  .ScenarioOutline('Adding <A> and <B> should be <Result>')
  .Given('the numbers <A> and <B>')
  .When('they are added', procedure(World: TCalculatorWorld)
    begin
      World.Calculator.Add(World.A, World.B);
    end)
  .&Then('the result is <Result>', procedure(World: TCalculatorWorld)
    begin
      Expect(World.Calculator.Result).ToEqual(World.Result);
    end)
  .Examples(
      [['A', 'B', 'Result'],
      [1, 1, 2],
      [10, 20, 30],
      [5, -2, 4],
      [0, 0, 0]]
    );
end.
