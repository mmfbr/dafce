unit Daf.MiniSpec.Expects;

interface
uses
  System.SysUtils;

type
  ExpectFail = class(Exception);
  TExpect = record
  strict private
    FValue: Variant;
  public
    class function Fail(Text: string): ExpectFail;overload;static;
    class function Fail(TextFmt: string; Args: array of const): ExpectFail;overload;static;
    constructor Create(const AValue: Variant);
    procedure ToEqual(const AExpected: Variant);
    procedure ToBeGreaterThan(const Value: Variant);
    procedure ToBeGreaterOrEqual(const AExpected: Variant);
    procedure ToBeLessOrEqual(const AExpected: Variant);
    procedure ToBeLessThan(const AExpected: Variant);
    procedure ToBeTrue;
    procedure ToBeFalse;
    procedure ToBeEmpty;
    procedure ToBeNull;
    procedure ToContain(const SubStr: string);
    procedure ToHaveCount(Expected: Integer);
  end;

implementation
uses
  System.StrUtils,
  System.Variants;

{ TExpect }

class function TExpect.Fail(Text: string): ExpectFail;
begin
  Result := ExpectFail.Create(Text);
end;

class function TExpect.Fail(TextFmt: string; Args: array of const): ExpectFail;
begin
  Result := ExpectFail.CreateFmt(TextFmt, Args);
end;

constructor TExpect.Create(const AValue: Variant);
begin
  FValue := AValue;
end;

procedure TExpect.ToEqual(const AExpected: Variant);
begin
  if FValue <> AExpected then
    raise Fail('Expected %s but got %s', [VarToStr(AExpected), VarToStr(FValue)]);
end;

procedure TExpect.ToBeLessThan(const AExpected: Variant);
begin
  if not (FValue < AExpected) then
    raise Fail('Expected less than %s but got %s', [VarToStr(AExpected), VarToStr(FValue)]);
end;

procedure TExpect.ToBeLessOrEqual(const AExpected: Variant);
begin
  if not (FValue <= AExpected) then
    raise Fail('Expected less or equal to %s but got %s', [VarToStr(AExpected), VarToStr(FValue)]);
end;

procedure TExpect.ToBeGreaterOrEqual(const AExpected: Variant);
begin
  if not (FValue >= AExpected) then
    raise Fail('Expected greater or equal to %s but got %s', [VarToStr(AExpected), VarToStr(FValue)]);
end;

procedure TExpect.ToBeTrue;
begin
  if not FValue then
    raise Fail('Expected value to be True');
end;

procedure TExpect.ToBeFalse;
begin
  if FValue then
    raise Fail('Expected value to be False');
end;

procedure TExpect.ToBeGreaterThan(const Value: Variant);
begin
  if FValue <= Value then
    raise Fail('Expected greater than %s but got %s', [VarToStr(Value), VarToStr(FValue)]);
end;

procedure TExpect.ToBeNull;
begin
  if not VarIsNull(FValue) then
    raise Fail('Expected value to be Null');
end;

procedure TExpect.ToContain(const SubStr: string);
begin
  if not ContainsText(VarToStr(FValue), SubStr) then
    raise Fail('Expected "%s" to contain "%s"', [VarToStr(FValue), SubStr]);
end;

procedure TExpect.ToBeEmpty;
begin
  if not VarIsEmpty(FValue) and (VarToStr(FValue) <> '') then
    raise Fail('Expected value to be empty');
end;

procedure TExpect.ToHaveCount(Expected: Integer);
begin
  if VarArrayDimCount(FValue) = 0 then
    raise Fail('Expected array value');
  if VarArrayHighBound(FValue, 1) - VarArrayLowBound(FValue, 1) + 1 <> Expected then
    raise Fail('Expected count %d but got %d', [Expected, VarArrayHighBound(FValue, 1) - VarArrayLowBound(FValue, 1) + 1]);
end;

end.
