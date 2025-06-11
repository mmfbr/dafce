# Ejemplos de DAF (Delphi Application Framework)

Este directorio contiene ejemplos prácticos que demuestran las diferentes características y patrones de DAF.

## Ejemplos Disponibles

### [MediatRSample](./MediatRSample/README.md)
Demuestra el uso del patrón Mediator en una aplicación VCL con CQRS y Dependency Injection.
- Implementación de CRUD de clientes
- Uso de comandos y queries
- Manejo de eventos
- Inyección de dependencias

### [ConfigSample](./ConfigSample/README.md)
Muestra el sistema de configuración de DAF.
- Configuración basada en archivos
- Configuración en memoria
- Múltiples proveedores de configuración
- Gestión de opciones

### [ConsoleSample](./ConsoleSample/README.md)
Ejemplo de aplicación de consola moderna con DAF.
- Configuración de aplicación
- Manejo de dependencias
- Patrones de diseño modernos
- Estructura modular

### [HostedService](./HostedService/README.md)
Demuestra la implementación de servicios hospedados.
- Servicios de larga duración
- Manejo de tareas en segundo plano
- Control de ciclo de vida
- Integración con el sistema de configuración

### 5. [PingProcess](./PingProcess/README.md)
Ejemplo de manejo de procesos del sistema.
- Uso de TSystemProcess
- Patrón Builder
- Manejo asíncrono
- Control de eventos de proceso

## Estructura de los Ejemplos

Cada ejemplo está organizado como un proyecto Delphi independiente y contiene:
- Archivo de proyecto (.dpr, .dproj)
- Documentación (README.md)
- Código fuente
- Recursos necesarios
- Carpeta `Files` (opcional) para archivos de configuración o datos

### Build Event para Archivos de Configuración

Los ejemplos que requieren archivos de configuración o datos utilizan una carpeta `Files` que se copia al directorio de salida durante la compilación. Para implementar esto en tu proyecto:

1. Crea una carpeta `Files` en el directorio del proyecto
2. Añade los archivos necesarios en esta carpeta
3. Configura el build event en el proyecto:

```batch
if exist "$(PROJECTDIR)\Files" xcopy "$(PROJECTDIR)\Files\*.*" "$(OUTPUTDIR)\$(OUTPUTNAME)\" /Y /S
```

## Cómo Usar los Ejemplos

1. Abrir el proyecto de ejemplo deseado
2. Revisar el README.md específico del ejemplo
3. Compilar y ejecutar
4. Explorar el código fuente para entender la implementación

## Requisitos

- Delphi 11 o superior
- DAF instalado
- Componentes VCL (para ejemplos con interfaz gráfica)

## Notas

- Los ejemplos están diseñados para ser educativos y demostrativos
- Cada ejemplo se centra en características específicas de DAF
- El código está comentado para facilitar la comprensión
