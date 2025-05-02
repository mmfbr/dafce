# HostedServiceWithTimer Sample

Este ejemplo muestra cómo implementar un `IHostedService` con un bucle controlado por temporizador usando `TThread` y `TEvent`.

## Objetivo

- Ejecutar una tarea periódica en segundo plano
- Detenerla limpiamente cuando la aplicación finaliza


## Resultado esperado

```
🟢 TTimedWorker.Start called
[10:32:01] TTimedWorker running...
[10:32:02] TTimedWorker running...
...
🔴 TTimedWorker.Stop called
```

## Casos de uso

- Workers periódicos
- Monitores de sistema
- Polling de APIs, colas, etc.

## Requisitos

- Delphi
- DAF con soporte para `IHostedService`
- 
# 🗭 DAF – ¿Cuándo usar `HostedService` y cuándo usar `MediatR`?

Una de las decisiones clave al desarrollar aplicaciones modernas con DAF es elegir **el patrón adecuado para ejecutar lógica de infraestructura o negocio**. Esta guía te ayuda a decidir entre usar un `HostedService` o un `MediatR Handler`.

---

## 🗱 HostedService

Un `HostedService` representa un **servicio de infraestructura de larga duración**, que:

- Se **inicia automáticamente** al arrancar la aplicación.
- Tiene **ciclo de vida propio** (`Start` / `Stop`).
- Puede ejecutarse en **hilo de fondo** (con `TTask`) o directamente.

### ✅ Cuándo usarlo

- Polling de base de datos, colas o servicios externos.
- Timers recurrentes (por ejemplo: cada 5 segundos).
- Servicios que necesitan vivir toda la vida de la app (caches, watchdogs).
- Tareas programadas o automáticas que no dependen de un trigger de dominio.

### 📌 Ejemplo

```delphi
type
  TEmailSyncWorker = class(THostedServiceBase)
  protected
    procedure Execute(const Token: ICancellationToken); override;
  end;
```

---

## 🎯 MediatR

`MediatR` implementa un patrón de mensajería para representar **acciones discretas o eventos del dominio**. Es ideal para modelar:

- Intenciones del usuario o sistema → `IRequest` (comandos).
- Notificaciones de eventos → `INotification`.

### ✅ Cuándo usarlo

- Cuando una acción debe ejecutarse **una vez y de forma explícita**.
- Si forma parte de la **capa de aplicación o dominio**.
- Cuando se dispara a raíz de un controlador, un cambio de estado o un evento.
- Para separar lógica de infraestructura del negocio.

### 📌 Ejemplo

```delphi
type
  TRefreshCacheCommand = class(TInterfacedObject, IRequest)
  end;

type
  TRefreshCacheHandler = class(TInterfacedObject, IRequestHandler<TRefreshCacheCommand>)
    procedure Handle(const Request: TRefreshCacheCommand);
  end;
```

---

## 🧠 Reglas prácticas

| Si... | Usa... |
|-------|--------|
| Necesita ejecutarse periódicamente | `HostedService` |
| Necesita hilo de fondo o cancelación por token | `HostedService` |
| Es una acción explícita disparada por la app | `MediatR Command` |
| Es una reacción a un evento | `MediatR Notification` |
| Se ejecuta solo una vez | `MediatR` |
| Necesita iniciarse automáticamente | `HostedService` |

---

## 📄 Consejo Delphi

Delphi no tiene `async/await` como en .NET, así que los `HostedServices` con `TTask.Run` deben:
- Capturar excepciones (`try..except`)
- Cancelarse con `ICancellationToken`
- Llamar a `Wait` en `Stop` para garantizar limpieza

---

## 📂 Conclusión

Usar correctamente `HostedService` y `MediatR` mejora:

- La claridad del diseño.
- El mantenimiento de la solución.
- La testabilidad de cada componente.

Ambos son herramientas potentes dentro de DAF. Elegir bien cuál aplicar hace tu código más limpio y tu arquitectura más robusta.

