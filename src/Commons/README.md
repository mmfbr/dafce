# TSystemProcess

**Unidad:** `Daf.SystemProcess`
**Framework:** DAF
**Versión:** Revisión actual
**Autoría:** Colaborativa

## ✨ Descripción

`TSystemProcess` es una clase de alto nivel diseñada para lanzar, controlar y supervisar procesos externos en Windows de forma asincrónica y orientada a eventos.
Su API es intuitiva para desarrolladores procedentes de .NET, permitiendo gestionar procesos con opciones como:

* Timeout configurable
* Captura de salida y errores (`stdout` / `stderr`)
* Callbacks de eventos (`OnCompleted`, `OnFailed`, `OnKilled`, etc.)
* Cancelación con `CancellationToken`
* Builder fluido con encadenamiento de métodos
* Matar procesos por código o desde `CTRL+C` con integración con `TShutdownHook`

---

## 🛩 Clases y Tipos

### `TSystemProcess.TStatus` (enum)

Estado final del proceso:

* `Running`
* `Completed`
* `Canceled`
* `Timeout`
* `Failed`

---

### `TProcessResult`

Registro con información final del proceso:

| Campo       | Tipo        | Descripción                            |
| ----------- | ----------- | -------------------------------------- |
| `Status`    | `TStatus`   | Estado final                           |
| `ExitCode`  | `DWORD`     | Código de salida del proceso           |
| `Duration`  | `TTimeSpan` | Tiempo total de ejecución              |
| `LastError` | `string`    | Descripción del último error           |
| `Succeeded` | `function`  | `True` si `Completed` y `ExitCode = 0` |

---

### `TSystemProcess`

Clase principal.

#### 🔧 Propiedades

| Propiedad          | Tipo                  | Descripción                                            |
| ------------------ | --------------------- | ------------------------------------------------------ |
| `CommandLine`      | `string`              | Comando completo a ejecutar                            |
| `WorkingDirectory` | `string`              | Directorio de trabajo opcional                         |
| `TimeoutMS`        | `Cardinal`            | Tiempo máximo en milisegundos (`INFINITE` por defecto) |
| `KillAfterTimeout` | `Boolean`             | Si se debe matar tras timeout                          |
| `HideWindow`       | `Boolean`             | Si se debe ocultar la ventana del proceso              |
| `IsRunning`        | `Boolean` (read-only) | `True` si el proceso sigue activo                      |

#### 📡 Callbacks

| Evento        | Tipo                                | Descripción                             |
| ------------- | ----------------------------------- | --------------------------------------- |
| `OnStdOut`    | `procedure(Text: string)`           | Cada línea de salida estándar           |
| `OnStdErr`    | `procedure(Text: string)`           | Cada línea de salida de error           |
| `OnIdle`      | `procedure(Result: TProcessResult)` | Llamado periódicamente mientras ejecuta |
| `OnCompleted` | `procedure(Result: TProcessResult)` | Al finalizar exitosamente               |
| `OnFailed`    | `procedure(Result: TProcessResult)` | Si `CreateProcess` falla o similar      |
| `OnCancelled` | `procedure(Result: TProcessResult)` | Si se cancela con token                 |
| `OnKilled`    | `procedure(Result: TProcessResult)` | Si se termina forzadamente              |

---

### `TBuilder`

Fluent API para construir procesos.

```pascal
var Process := TSystemProcess.Builder
  .Command('ping.exe')
  .CmdArgs(['127.0.0.1'])
  .Timeout(10000)
  .OnStdOut(...)
  .OnCompleted(...)
  .Build;
```

---

## ✅ Métodos principales

### `Execute(CancellationToken: ICancellationToken = nil): TProcessResult`

Ejecución síncrona. Captura todos los eventos y devuelve el resultado final.

### `ExecuteAsync(CancellationToken: ICancellationToken = nil): IFuture<TProcessResult>`

Ejecución en segundo plano con resultado futuro.

### `Kill`

Mata el proceso lanzado (por `PID`). Internamente usa `TerminateProcess` y marca `FKillRequested := True`.

> **Nota:** no garantiza el cierre de procesos del sistema o GUI como `notepad.exe`.

---

## 🚫 Limitaciones conocidas

* Algunos procesos GUI como `notepad.exe`, `calc.exe`, etc., **no pueden ser terminados** correctamente debido a protecciones del sistema o porque delegan en procesos intermedios.
* El PID devuelto por `CreateProcess` puede no corresponder con el proceso visible.
* El uso de `HideWindow(True)` en apps GUI puede hacer que el proceso se vuelva incontrolable (invisible pero no matable).

---

## 🛠 Integración con `TShutdownHook`

Puedes conectar la finalización del sistema (como `CTRL+C`) para cancelar procesos:

```pascal
TShutdownHook.OnShutdownRequested := procedure
begin
  Process.Kill;
end;
```

---

## 🔄 Ciclo de vida

```plaintext
Builder → Build → Execute/ExecuteAsync →
  [OnIdle*] → (Cancel/Kill/Timeout/Complete) →
  OnCompleted / OnKilled / OnCancelled / OnFailed
```

---

## 🔬 Ejemplo práctico

```pascal
var Process := TSystemProcess.Builder
  .Command('cmd.exe')
  .CmdArgs(['/C', 'ping 127.0.0.1'])
  .Timeout(10000)
  .OnStdOut(procedure(Text: string) begin Writeln(Text); end)
  .OnCompleted(procedure(Result: TProcessResult)
  begin
    Writeln('ExitCode: ', Result.ExitCode);
  end)
  .Build;

Process.ExecuteAsync;
```

---

## 📌 Recomendaciones de uso

* Usa `ExecuteAsync` en apps con UI o consola que deban mantenerse reactivas.
* No uses `Kill` con procesos del sistema o GUI protegidos.
* Usa `HideWindow(True)` solo con procesos de consola sin GUI.
