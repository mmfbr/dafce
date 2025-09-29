unit Daf.AppModule;

interface
uses
  DAF.Extensions.DependencyInjection;

type
  IAppModule = interface(IInvokable)
    ['{3FA56942-21D1-4B08-ABD4-F4F82F48F36C}']
    procedure AddServices(const ServiceCollection: IServiceCollection);
  end;

implementation

end.
