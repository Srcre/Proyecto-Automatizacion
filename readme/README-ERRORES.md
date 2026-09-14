# README - Historial de errores y soluciones

## Proyecto
Herramienta de Soporte TI - Preparar Computador

## Regla de documentación
Cada corrección del código debe quedar registrada con el nombre del error, su síntoma, causa y solución.

---

## Error 1: `New-LocalUser` fallaba por una descripción demasiado larga

**Síntoma:** la creación de la cuenta fallaba al ejecutar `New-LocalUser`.

**Causa:** el texto utilizado en `-Description` superaba la longitud aceptada para la cuenta local.

**Solución:** se redujo la descripción a un texto corto: `Cuenta de prueba`.

**Estado:** RESUELTO

---

## Error 2: El script mostraba `[OK]` aunque la creación del usuario había fallado

**Síntoma:** `New-LocalUser` fallaba, pero el script continuaba y mostraba mensajes posteriores como si la cuenta hubiera sido creada.

**Causa:** el error no detenía correctamente la secuencia de preparación.

**Solución:** se incorporó `-ErrorAction Stop` y manejo mediante `try/catch`, de modo que un fallo real interrumpa la preparación y entregue un resultado `ERROR`.

**Estado:** RESUELTO

---

## Error 3: Los nombres de grupos variaban según el idioma de Windows

**Síntoma:** el script podía no encontrar `Administrators`/`Administradores` o `Users`/`Usuarios`.

**Causa:** los nombres visibles de los grupos locales dependen del idioma de Windows.

**Solución:** se identifican los grupos mediante sus SID conocidos: `S-1-5-32-544` para Administradores y `S-1-5-32-545` para Usuarios.

**Estado:** RESUELTO

---

## Error 4: Verificación incorrecta de "Contraseña nunca expira"

**Síntoma:** la interfaz podía indicar que la verificación había fallado aunque la configuración de la cuenta fuera correcta.

**Causa:** la propiedad utilizada desde `Get-LocalUser` no resultaba fiable para esa verificación en el escenario probado.

**Solución:** se cambió la verificación a `Win32_UserAccount.PasswordExpires` mediante CIM.

**Estado:** RESUELTO

---

## Error 5: Falso error después de una preparación exitosa

**Síntoma:** el usuario se creaba y el log terminaba correctamente, pero la GUI podía mostrar una notificación de error adicional.

**Causa:** la rutina de finalización podía ejecutarse más de una vez por interacción con el `System.Windows.Forms.Timer` y el ciclo de mensajes.

**Solución:** se incorporaron los bloqueos `FinalizacionEnCurso`, `FinalizacionProcesada` y `NotificacionMostrada`, además de detener el Timer antes de la finalización y liberar recursos antes de dejar el estado en `INACTIVO`.

**Versión de referencia:** V4.4.2

**Estado:** RESUELTO

---

## Error 6: La GUI se vuelve inestable después de varias ejecuciones consecutivas

**Síntoma:** al ejecutar varias preparaciones desde la misma ventana, después de aproximadamente tres cuentas la aplicación puede quedar sin responder.

**Prueba realizada:** se comprobó que Windows puede crear al menos 10 cuentas locales consecutivas directamente con PowerShell. Por lo tanto, el problema no corresponde a un límite aparente de cuentas locales.

**Causa:** EN INVESTIGACIÓN. El foco está en el ciclo de vida de `Runspace`, `PowerShell`, `BeginInvoke`, `EndInvoke`, `Dispose` y `System.Windows.Forms.Timer` entre ejecuciones consecutivas.

**Solución actual:** V4.4.3 agrega instrumentación de diagnóstico para registrar el ciclo de vida completo y localizar exactamente la etapa en la que se produce la inestabilidad.

**Estado:** EN INVESTIGACIÓN

---

# V4.4.3 Diagnóstico

## Objetivo
Mantener la lógica funcional de V4.4.2 y agregar trazas para diagnosticar ejecuciones repetidas sin introducir todavía creación masiva de usuarios.

## Trazas incorporadas
- Número de ejecución.
- Creación y apertura del Runspace.
- Creación y asociación de PowerShell.
- Carga del motor.
- `BeginInvoke`.
- `EndInvoke`.
- Procesamiento de colas.
- `PowerShell.Stop`.
- `PowerShell.Dispose`.
- `Runspace.Close`.
- `Runspace.Dispose`.
- Estado `INACTIVO`.

## Prueba TI
Ejecutar la misma aplicación consecutivamente y observar: `#1`, `#2`, `#3`, ... hasta `#10`.

Si se congela, el último mensaje `[DEBUG]` registrado será el primer indicador del punto donde investigar.

---

## Error 7: Falso error inmediatamente después de "FIN EJECUCIÓN"

**Versión detectada:** V4.4.3 Diagnóstico  
**Versión corregida:** V4.4.4

**Síntoma:** todas las operaciones de la preparación terminaban correctamente y el log llegaba a:

```text
[DEBUG] ===== FIN EJECUCIÓN #X =====
```

Sin embargo, inmediatamente después aparecía nuevamente la ventana de error. La preparación real del usuario era correcta.

**Causa:** `FinalizacionProcesada` se establecía en `$true`, pero el controlador del `System.Windows.Forms.Timer` solamente comprobaba `FinalizacionEnCurso`. Durante el `MessageBox`, Windows mantiene un ciclo de mensajes anidado y podía procesarse otro `Tick`. Cuando la primera finalización terminaba y liberaba `FinalizacionEnCurso`, ese `Tick` pendiente podía entrar nuevamente a la rutina de finalización, aunque la ejecución ya había sido procesada y los objetos `PowerShell`/`Runspace` ya habían sido liberados.

**Solución:** el `Timer` ahora sale inmediatamente si `FinalizacionEnCurso` **o** `FinalizacionProcesada` están activos:

```powershell
if (
    $script:FinalizacionEnCurso -or
    $script:FinalizacionProcesada
) {
    return
}
```

El bloqueo `FinalizacionProcesada` se reinicia únicamente al comenzar una nueva ejecución. De esta manera, una ejecución solo puede finalizar una vez, incluso si queda un `Tick` pendiente en la cola de mensajes de Windows.

**Estado:** RESUELTO

---

## Error 8: Segundo mensaje de error después de una finalización aparentemente correcta

**Versión detectada:** V4.4.4  
**Versión corregida:** V4.4.5

**Síntoma:** la preparación del usuario termina correctamente, el estado de la GUI muestra `Proceso completado correctamente.` y el registro llega hasta `FIN EJECUCIÓN #X`, pero aparece posteriormente una notificación de error.

**Causa:** la rutina de finalización estaba repartida dentro del evento del `System.Windows.Forms.Timer` y el bloqueo `FinalizacionEnCurso` se liberaba al final. Esto dejaba abierta la posibilidad de que un evento pendiente del ciclo de mensajes intentara procesar nuevamente una ejecución ya finalizada. La existencia de varios indicadores de estado no garantizaba por sí sola un único punto de salida.

**Solución:** se rediseñó la finalización para que exista un único punto de decisión dentro del `Tick`. `FinalizacionProcesada` se activa inmediatamente antes de comenzar `EndInvoke` y permanece activa durante toda la vida de la ejecución hasta que comienza la siguiente. `FinalizacionEnCurso` también permanece activa hasta la siguiente ejecución. El `Timer` se detiene antes de `EndInvoke`, los recursos se liberan antes de la notificación y el estado pasa a `INACTIVO` antes de mostrar el `MessageBox`. Los eventos posteriores quedan descartados.

Además, el resultado final se trata exclusivamente mediante el objeto estructurado entregado por el motor (`SUCCESS`/`ERROR`, usuario, mensaje y código), evitando inferir el resultado a partir del contenido de las colas.

**Estado:** PENDIENTE DE PRUEBA EN V4.4.5
