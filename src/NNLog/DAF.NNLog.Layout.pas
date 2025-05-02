unit DAF.NNLog.Layout;

interface

uses
  System.SysUtils,
  System.Classes,
  System.RegularExpressions,
  System.Generics.Collections,
  Daf.Extensions.Logging;

type
  TLayoutRenderer = reference to function(const Arg: string; const Entry: TLogEntry): string;
  TLogLayoutEngine = class
  private
  public
    class function ResolveToken(const Token: string; const Entry: TLogEntry): string;
    class procedure RegisterRenderer(const Name: string; const Renderer: TLayoutRenderer);
    class function ResolveLayout(const Layout: string; const Entry: TLogEntry): string;
  end;

implementation

uses
  System.TypInfo,
  System.Generics.Defaults,
  System.Rtti,
  System.StrUtils,
  System.Character;

var
  RendererMap: TDictionary<string, TLayoutRenderer> = nil;

{ TLogLayoutEngine }

class procedure TLogLayoutEngine.RegisterRenderer(const Name: string; const Renderer: TLayoutRenderer);
begin
  if RendererMap = nil then
    RendererMap := TDictionary<string, TLayoutRenderer>.Create(TIStringComparer.Ordinal);
  RendererMap.AddOrSetValue(Name, Renderer);
end;

class function TLogLayoutEngine.ResolveToken(const Token: string; const Entry: TLogEntry): string;
var
  Name, Arg: string;
  Renderer: TLayoutRenderer;
begin
  var ColonPos := Token.IndexOf(':');
  if ColonPos > 0 then
  begin
    Name := Token.Substring(0, ColonPos);
    Arg := Token.Substring(ColonPos + 1);
  end
  else
  begin
    Name := Token;
    Arg := '';
  end;
  Renderer := nil;
  if Assigned(RendererMap) and RendererMap.TryGetValue(Name, Renderer) then
    Result := Renderer(Arg, Entry)
  else
    Result := '';
  Renderer := nil;
end;

class function TLogLayoutEngine.ResolveLayout(const Layout: string; const Entry: TLogEntry): string;
begin
  Result := Layout;
  var Matches := TRegEx.Matches(Layout, '\$\{(.*?)\}');
  for var Match in Matches do
  begin
    var Token := Match.Groups[1].Value;
    var Resolved := ResolveToken(Token, Entry);
    Result := Result.Replace(Match.Value, Resolved);
  end;
end;

initialization
finalization
  for var Key in RendererMap.Keys do
  begin
    RendererMap[Key] := nil;
  end;
  FreeAndNil(RendererMap);
end.

