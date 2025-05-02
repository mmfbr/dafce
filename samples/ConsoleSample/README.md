# ConsoleSample

Este ejemplo muestra cómo utilizar HostBuilder para construir una aplicación de consola moderna, al estilo de .NET.
En particular, muestra:

- Construir un `Host` con `THostBuilder`
- Acceso a IHostEnvironment para calcular la ruta del fichero de configuración
- Usar `IConfiguration` con una fuente JSON (`appsettings.json`)
- Enlazar (Bind) la configuración con un tipo propio en la aplicación.
- Inyectar un servicio mediante una factoria para iniciarlo con valores que dependen de la configuración
- Iniciar y detener el Host correctamente.
- Solicitar al Host que esepere ctl-c antes de terminar

## Configuración

Se encuentra en Files/appsettings.json. El contenido de Files se copia automaticante
a una carpeta de salida junto al exe y con su mismo nombre.


