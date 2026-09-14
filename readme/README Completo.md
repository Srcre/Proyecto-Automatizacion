# Proyecto Automatización

## Estado actual

Proyecto PowerShell para preparar y verificar computadores Windows para
administración remota mediante WinRM.

La arquitectura evolucionó desde un script/GUI monolítico hacia módulos
independientes. Cada módulo debe configurar una responsabilidad
concreta, devolver resultados estructurados y manejar sus propios
errores sin derribar el resto del sistema.

### Estructura

``` text
Proyecto-Automatizacion
├── PREPARAR-PC.ps1
├── README.md
├── Modulos
│   ├── Usuario.ps1
│   ├── Permisos.ps1
│   ├── Contrasena.ps1
│   ├── WinRM.ps1
│   ├── Firewall.ps1
│   └── Verificacion.ps1
├── Configuracion
├── Logs
└── Versiones
```

------------------------------------------------------------------------

# 1. Objetivo

Automatizar y verificar:

1.  Creación y habilitación de usuarios locales.
2.  Privilegios estándar/administrador.
3.  Opciones de contraseña.
4.  WinRM.
5.  Firewall para WinRM.
6.  Verificación final.
7.  Integración futura con una GUI.

Principio de diseño:

> Un módulo que falla no debe provocar que toda la aplicación falle.

------------------------------------------------------------------------

# 2. Contrato de resultados

Los módulos devuelven objetos estructurados, por ejemplo:

``` powershell
[PSCustomObject]@{
    Estado  = "SUCCESS"
    Usuario = "prueba3"
    Mensaje = "Configuracion completada."
    Codigo  = 0
}
```

Estados:

  Estado    Significado
  --------- --------------------------------------------------
  SUCCESS   Correcto
  WARNING   Atención requerida, pero no necesariamente fallo
  ERROR     No se pudo cumplir o verificar lo solicitado

Esto permitirá que la futura GUI muestre cada módulo de manera
independiente.

------------------------------------------------------------------------

# 3. Usuario.ps1

Función principal:

``` powershell
New-LocalSupportUser
```

Responsabilidades:

-   Comprobar si el usuario existe.
-   Crear la cuenta local.
-   Habilitarla.
-   Manejar errores.
-   Devolver resultado estructurado.

Ejemplo:

``` powershell
. .\Modulos\Usuario.ps1

New-LocalSupportUser `
    -NombreUsuario "prueba3" `
    -Password "prueba"
```

La contraseña `prueba` es exclusivamente de laboratorio y no debe
utilizarse en producción.

------------------------------------------------------------------------

# 4. Permisos.ps1

Funciones:

``` powershell
Get-LocalGroupBySid
Add-LocalUserPermission
```

Permite:

-   Usuario estándar.
-   Administrador.
-   Ambos.
-   Validación de configuración.

Se utilizan SID para no depender del idioma de Windows:

``` text
S-1-5-32-544 = Administradores/Administrators
S-1-5-32-545 = Usuarios/Users
```

Ejemplo:

``` powershell
. .\Modulos\Permisos.ps1

Add-LocalUserPermission `
    -NombreUsuario "prueba3" `
    -UsuarioEstandar $true `
    -Administrador $false
```

------------------------------------------------------------------------

# 5. Contrasena.ps1

Función:

``` powershell
Set-LocalPasswordOptions
```

Configura:

``` text
ContrasenaNuncaExpira
UsuarioPuedeCambiarContrasena
```

Ejemplo:

``` powershell
. .\Modulos\Contrasena.ps1

Set-LocalPasswordOptions `
    -NombreUsuario "prueba3" `
    -ContrasenaNuncaExpira $true `
    -UsuarioPuedeCambiarContrasena $false
```

Para verificar expiración se utiliza
`Win32_UserAccount.PasswordExpires`, porque la lectura utilizada de
`Get-LocalUser.PasswordNeverExpires` no resultó fiable para este
escenario.

Windows puede impedir quitar la capacidad de cambiar contraseña al
último administrador local. Esa condición debe tratarse de forma
controlada.

------------------------------------------------------------------------

# 6. WinRM.ps1

Función:

``` powershell
Enable-LocalWinRM
```

Comprueba/configura:

-   Privilegios administrativos.
-   Servicio WinRM.
-   Estado Running.
-   Inicio Automatic.
-   Listener.
-   Windows PowerShell 5.1.
-   Windows PowerShell Remoting.
-   Endpoint PowerShell.

Configuración de laboratorio:

``` text
Servicio : Running
Inicio   : Automatic
Transporte: HTTP
Puerto   : 5985
```

## PowerShell 7 vs Windows PowerShell 5.1

Se detectó la advertencia de que `Enable-PSRemoting` ejecutado desde
PowerShell 7 afecta las configuraciones de PowerShell 6+ y no
necesariamente las de Windows PowerShell.

La configuración de Windows PowerShell Remoting se verificó desde
Windows PowerShell 5.1.

------------------------------------------------------------------------

# 7. Firewall.ps1

Función:

``` powershell
Enable-LocalFirewallWinRM
```

Comprueba:

-   Perfil de red.
-   Estado del Firewall.
-   Reglas WinRM.
-   Dirección.
-   Acción.
-   Protocolo.
-   Puerto.
-   Perfil.
-   Direcciones remotas.

WinRM HTTP utiliza:

``` text
TCP 5985
```

En el laboratorio el perfil activo fue:

``` text
Private
```

La regla válida encontrada fue:

``` text
WINRM-HTTP-In-TCP-NoScope
```

con:

``` text
Enabled       : True
Direction     : Inbound
Action        : Allow
Protocol      : TCP
LocalPort     : 5985
Profile       : Domain, Private
RemoteAddress : Any
```

## Corrección realizada

Inicialmente se buscaba una regla asociada específicamente al servicio
WinRM y no se encontraba.

Se corrigió la lógica para localizar reglas internas de WinRM y validar:

``` text
Enabled
+ Inbound
+ Allow
+ Perfil compatible
+ TCP
+ Puerto 5985
```

Resultado final:

``` text
SUCCESS
Codigo: 0
```

------------------------------------------------------------------------

# 8. Verificacion.ps1 v1.2

Función principal:

``` powershell
Test-LocalComputerConfiguration
```

No modifica el equipo. Solo consulta y compara el estado actual con el
estado esperado.

Parámetros:

``` powershell
-NombreUsuario
-UsuarioEstandar
-Administrador
-ContrasenaNuncaExpira
-UsuarioPuedeCambiarContrasena
```

Ejemplo:

``` powershell
$resultado = Test-LocalComputerConfiguration `
    -NombreUsuario "prueba3" `
    -UsuarioEstandar $true `
    -Administrador $false `
    -ContrasenaNuncaExpira $true `
    -UsuarioPuedeCambiarContrasena $false
```

Cada comprobación se guarda en:

``` powershell
$resultado.Verificaciones
```

Para verlas:

``` powershell
$resultado.Verificaciones |
    Format-Table Modulo, Prueba, Estado, Detalle, Codigo -AutoSize
```

Para mostrar solo problemas:

``` powershell
$resultado.Verificaciones |
    Where-Object { $_.Estado -ne "SUCCESS" } |
    Format-Table Modulo, Prueba, Estado, Detalle, Codigo -AutoSize
```

## Qué verifica

1.  Privilegios administrativos.
2.  Existencia del usuario.
3.  Cuenta habilitada.
4.  Grupo Usuarios.
5.  Grupo Administradores.
6.  Expiración de contraseña.
7.  Cambio de contraseña.
8.  Servicio WinRM.
9.  Inicio automático de WinRM.
10. Listener HTTP 5985.
11. Endpoint Microsoft.PowerShell.
12. Perfil de red.
13. Firewall.
14. Regla WinRM TCP 5985.

## Endpoint Microsoft.PowerShell

No se utiliza:

``` powershell
Get-PSSessionConfiguration
```

porque provocó:

``` text
COM object that has been separated from its underlying RCW cannot be used.
```

La alternativa utiliza:

``` text
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Plugin\Microsoft.PowerShell
```

y verifica que el plugin exista y tenga:

``` text
Enabled="true"
```

El laboratorio confirmó que existen:

``` text
Microsoft.PowerShell
Microsoft.PowerShell.WorkFlow
Microsoft.PowerShell32
PowerShell.7
PowerShell.7.6.5
```

------------------------------------------------------------------------

# 9. Errores documentados

## ERR-001: Markdown dentro de .ps1

### Síntoma

Se incluyeron delimitadores:

``` text
```powershell
```

dentro de un archivo `.ps1`.

### Solución

Los delimitadores Markdown solo pertenecen al README/documentación. El
`.ps1` debe contener código PowerShell puro.

------------------------------------------------------------------------

## ERR-002: Description demasiado larga

### Síntoma

`New-LocalUser` rechazó una descripción demasiado extensa.

### Solución

Utilizar una descripción corta, por ejemplo:

``` text
Cuenta creada por herramienta TI
```

------------------------------------------------------------------------

## ERR-003: El script continuaba después de un fallo

### Síntoma

Una creación de usuario fallaba, pero el flujo continuaba y podía
mostrar `[OK]` incorrectamente.

### Solución

Usar:

``` powershell
-ErrorAction Stop
```

junto con:

``` powershell
try { }
catch { }
```

------------------------------------------------------------------------

## ERR-004: Grupos dependientes del idioma

### Síntoma

El nombre `Administrators` no existía porque Windows estaba en español.

### Solución

Usar SID:

``` text
S-1-5-32-544
S-1-5-32-545
```

------------------------------------------------------------------------

## ERR-005: Verificación de PasswordNeverExpires

### Síntoma

`Get-LocalUser.PasswordNeverExpires` no resultó fiable para la
comprobación utilizada.

### Solución

Consultar:

``` powershell
Get-CimInstance Win32_UserAccount
```

y utilizar `PasswordExpires`.

------------------------------------------------------------------------

## ERR-006: Último administrador no puede tener cambio de contraseña bloqueado

### Síntoma

Windows devuelve una condición equivalente a:

``` text
No se puede quitar el último administrador
```

al intentar impedir que ese administrador cambie su contraseña.

### Solución

No forzar la operación. Informar la condición y mantener habilitado el
cambio de contraseña cuando Windows lo requiera.

------------------------------------------------------------------------

## ERR-007: Error RCW en WinRM

### Síntoma

Durante una versión anterior apareció:

``` text
COM object that has been separated from its underlying RCW cannot be used.
```

### Diagnóstico

El problema apareció durante operaciones relacionadas con objetos de
WinRM/WSMan.

### Solución aplicada

Reducir el uso innecesario de objetos complejos y evitar conservar
objetos COM/CIM más tiempo del necesario. En la verificación del
endpoint se eliminó `Get-PSSessionConfiguration`.

------------------------------------------------------------------------

## ERR-008: Falso error de la GUI después de SUCCESS

### Síntoma

Una ejecución terminaba correctamente, pero la GUI mostraba
posteriormente un error.

### Causa

Problemas de orden entre cola de resultados, Timer, finalización y
limpieza del Runspace.

### Solución

Se introdujeron resultados estructurados y controles de finalización, y
posteriormente se migró la arquitectura hacia módulos independientes.

------------------------------------------------------------------------

## ERR-009: Estado válido interpretado como WARNING

### Síntoma

La verificación mostraba:

``` text
WARNING: El usuario no puede cambiar la contraseña.
```

aunque se había solicitado exactamente:

``` text
UsuarioPuedeCambiarContrasena = False
```

### Causa

El verificador conocía el estado actual pero no el estado esperado.

### Solución

Agregar parámetros:

``` powershell
-ContrasenaNuncaExpira
-UsuarioPuedeCambiarContrasena
```

y comparar:

``` text
Estado actual == Estado esperado
```

Si coinciden:

``` text
SUCCESS
```

Si no coinciden:

``` text
ERROR
```

------------------------------------------------------------------------

# 10. Versiones anteriores de la GUI

Se desarrollaron versiones V1 a V4.

La versión V4.2.2 fue utilizada como referencia estable.

La V4.4 separó motor y GUI:

``` text
MOTOR-PREPARAR-PC-v4.4.1.ps1
PREPARAR-PC-GUI-v4.4.1.ps1
```

Se detectaron problemas de Runspace, Timer, finalización y RCW.

La decisión arquitectónica posterior fue abandonar la dependencia de una
única cadena monolítica y construir módulos independientes.

------------------------------------------------------------------------

# 11. Pruebas realizadas

Se probaron usuarios de laboratorio como:

``` text
prueba
prueba1
prueba2
prueba3
```

También se crearon externamente:

``` text
testauto1
testauto2
...
testauto10
```

Las diez cuentas pudieron crearse, descartando un supuesto límite de 2 o
3 usuarios como causa de los problemas anteriores de la GUI.

## Prueba actual

Usuario:

``` text
prueba3
```

Configuración:

``` text
Usuario estándar                = True
Administrador                   = False
Contraseña nunca expira         = True
Usuario puede cambiar password  = False
```

La prueba de los módulos fue satisfactoria.

------------------------------------------------------------------------

# 12. Flujo manual

Desde la raíz del proyecto:

``` powershell
. .\Modulos\Usuario.ps1
New-LocalSupportUser -NombreUsuario "prueba3" -Password "prueba"

. .\Modulos\Permisos.ps1
Add-LocalUserPermission -NombreUsuario "prueba3" -UsuarioEstandar $true -Administrador $false

. .\Modulos\Contrasena.ps1
Set-LocalPasswordOptions -NombreUsuario "prueba3" -ContrasenaNuncaExpira $true -UsuarioPuedeCambiarContrasena $false

. .\Modulos\WinRM.ps1
Enable-LocalWinRM

. .\Modulos\Firewall.ps1
Enable-LocalFirewallWinRM

. .\Modulos\Verificacion.ps1
Test-LocalComputerConfiguration `
    -NombreUsuario "prueba3" `
    -UsuarioEstandar $true `
    -Administrador $false `
    -ContrasenaNuncaExpira $true `
    -UsuarioPuedeCambiarContrasena $false
```

------------------------------------------------------------------------

# 13. Próxima arquitectura

La próxima etapa será crear un orquestador.

``` text
GUI
 |
 v
ORQUESTADOR
 |
 +--> Usuario
 |
 +--> Permisos
 |
 +--> Contrasena
 |
 +--> WinRM
 |
 +--> Firewall
 |
 +--> Verificacion
 |
 v
RESULTADOS
```

El orquestador debe:

-   Ejecutar módulos independientemente.
-   Recibir resultados estructurados.
-   Registrar resultados.
-   Continuar después de errores recuperables.
-   Ejecutar la verificación final.
-   Entregar los resultados a la GUI.

------------------------------------------------------------------------

# 14. GUI futura

La GUI no debería interpretar texto de consola.

Debe consumir:

``` powershell
$resultado.Verificaciones
```

y representar:

``` text
Usuario       🟢
Permisos      🟢
Contraseña    🟢
WinRM         🟢
Firewall      🟢
```

o:

``` text
Usuario       🟢
Permisos      🟢
Contraseña    🔴
WinRM         🟢
Firewall      🟢
```

El fallo de un módulo no debe cerrar ni inutilizar la aplicación.

------------------------------------------------------------------------

# 15. Seguridad

Este proyecto se está probando en laboratorio.

Antes de producción:

-   No utilizar contraseñas de laboratorio.
-   No almacenar contraseñas en texto plano.
-   No exponer WinRM indiscriminadamente a Internet.
-   Restringir TCP 5985 mediante controles de red apropiados.
-   Preferir red administrativa/VPN y reglas de Firewall limitadas.
-   Ejecutar con privilegios administrativos solo cuando sea necesario.

------------------------------------------------------------------------

# 16. Metodología

Cada módulo debe seguir:

``` text
Diseño
  ↓
Código
  ↓
Prueba positiva
  ↓
Prueba negativa
  ↓
Corrección
  ↓
Documentación
  ↓
Aprobación
  ↓
Integración
```

No se debe integrar un módulo que todavía no haya sido validado
independientemente.

------------------------------------------------------------------------

# 17. Estado del proyecto

  Componente                   Estado
  ---------------------------- --------------
  Usuario.ps1                  ✅ Validado
  Permisos.ps1                 ✅ Validado
  Contrasena.ps1               ✅ Validado
  WinRM.ps1                    ✅ Validado
  Firewall.ps1                 ✅ Validado
  Verificacion.ps1 v1.2        ✅ Validado
  Orquestador                  ⏳ Pendiente
  Sistema de Logs              ⏳ Pendiente
  Configuración centralizada   ⏳ Pendiente
  GUI modular                  ⏳ Pendiente
  Empaquetado para TI          ⏳ Pendiente

------------------------------------------------------------------------

# 18. Principio final del proyecto

El sistema debe pasar de:

``` text
"Ejecuté un script y dijo OK"
```

a:

``` text
"Cada componente fue configurado,
cada resultado fue registrado,
y el estado real del equipo fue verificado."
```

Ese es el objetivo técnico de Proyecto Automatización.

------------------------------------------------------------------------

**Última actualización:** 09-09-2026\
**Arquitectura:** Modular\
**Último módulo validado:** Verificacion.ps1 v1.2

============================================================
ERROR: INCOMPATIBILIDAD CON TRYParseExact
============================================================

Archivo:
Modulos\Logs.ps1

Funcion:
Get-LocalPreparationLog

Problema:
La llamada a [DateTime]::TryParseExact() con cinco
argumentos generaba un error de sobrecarga en PowerShell:

Cannot find an overload for "TryParseExact" and the
argument count: "5".

Consecuencia:
Get-LocalPreparationLog terminaba con:

Estado    : ERROR
Codigo    : 3
Registros : {}

Solucion:
Se reemplazo TryParseExact por DateTime.ParseExact()
dentro de un bloque try/catch.

Resultado:
La fecha se convierte mediante una sobrecarga compatible
y un registro con fecha invalida no detiene la lectura
completa de los Logs.

Estado:
CORREGIDO
============================================================