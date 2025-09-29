unit Daf.AppModule.DependencyInjection;

interface
uses
  System.TypInfo,
  System.Rtti,
  Daf.Extensions.DependencyInjection,
  Daf.AppModule;

type
  TAppModule = class(TInterfacedObject, IAppModule)
  public
    procedure AddServices(const ServiceCollection: IServiceCollection);virtual;
  end;

  TAppModuleServiceCollection = record helper for IServiceCollection
  public
    procedure AddModules(Package: TRttiPackage);
  end;

    // In case of previous helper goes shadowed
  AppModules = class
  public
    class procedure Add(ServiceCollection: IServiceCollection; Package: TRttiPackage);
  end;

implementation
uses
  System.SysUtils,
  System.Generics.Collections,
  Daf.Rtti;


{ TAppModule }

procedure TAppModule.AddServices(const ServiceCollection: IServiceCollection);
begin

end;

{ TAppModuleServiceCollection }
var Visited: TArray<string>;
procedure TAppModuleServiceCollection.AddModules(Package: TRttiPackage);
begin
  if TArray.Contains(Visited, Package.Name) then Exit;
  var More: TArray<string> := [Package.Name];
  Visited := TArray.Concat<string>([Visited, More]);
  var ServiceCollection := Self;
  Package.DiscoverImpl<IAppModule>(False,True,
    procedure(RIntf: TRttiInterfaceType; AClass: TRttiInstanceType)
    begin
      var Instance := AClass.MetaclassType.Create;
      var Module: IAppModule;
      Supports(Instance, IAppModule, Module);
      Module.AddServices(ServiceCollection);
  end);
end;

{ AppModules }

class procedure AppModules.Add(ServiceCollection: IServiceCollection; Package: TRttiPackage);
begin
  ServiceCollection.AddModules(Package);
end;

end.
