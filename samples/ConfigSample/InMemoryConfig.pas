unit InMemoryConfig;

interface

uses
  System.Generics.Collections,
  Daf.Extensions.Configuration,
  Daf.Configuration.Builder,
  Daf.Configuration.Memory;

type
  TInMemoryConfigSample = class
  public
    class procedure Run;
  end;

implementation

{ TInMemoryConfigSample }

class procedure TInMemoryConfigSample.Run;
var
  Config: IConfigurationRoot;
  Title: string;
  Dict: TDictionary<string, string>;
begin
  // Crear el diccionario con configuraciones
  Dict := TDictionary<string, string>.Create;
  Dict.Add('App:Title', 'Mi Aplicación Delphi');
  Dict.Add('App:Version', '1.0.0');


  // Crear el builder y agregar la fuente
  var Builder: IConfigurationBuilder := TConfigurationBuilder.Create;

  // Source Onws Dict by default
  MemoryConfig.AddCollection(Builder, Dict);

  // Construir la configuración
  Config := Builder.Build;

  // Obtener valores
  Title := Config['App:Title'];
  Writeln('Título: ' + Title);
  Writeln('Versión: ' + Config['App:Version']);

  Config['App:Title'] := 'Aplicación Actualizada';

  // Verificar nuevo valor
  Writeln('Título actualizado: ' + Config['App:Title']);
end;
end.
