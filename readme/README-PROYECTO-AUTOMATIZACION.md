# Proyecto Automatización

## Documentación técnica completa

**Versión documental:** 1.0\
**Plataforma:** Windows\
**Lenguaje:** PowerShell\
**Arquitectura:** Modular

------------------------------------------------------------------------

## 1. Objetivo

`Proyecto-Automatizacion` es una herramienta de administración de
equipos Windows desarrollada en PowerShell. Su objetivo es automatizar
la preparación de un computador para soporte y administración remota,
separando cada responsabilidad en módulos independientes.

La arquitectura actual sigue este principio:

> Una responsabilidad, un módulo, una función principal, manejo de
> errores, verificación y resultado estructurado.

------------------------------------------------------------------------

## 2. Estructura del proyecto

``` text
Proyecto-Automatizacion
│
├── PREPARAR-PC.ps1
├── README.md
├── README-ERRORES.md
│
├── Modulos
│   ├── usuario.ps1
│   ├── permisos.ps1
│   ├── contrasena.ps1
│   ├── winrm.ps1
│   ├── firewall.ps1
│   └── verificacion.ps1
│
├── Config
├── Logs
└── Versiones
```

### Carpetas

-   **Modulos:** lógica independiente de cada función.
-   **Configuracion:** parámetros externos que posteriormente se
    separarán del código.
-   **Logs:** registros de ejecución.
-   **Versiones:** copias de versiones estables.
-   **README-ERRORES.md:** historial de problemas y soluciones.

------------------------------------------------------------------------

## 3. Arquitectura

El flujo final será:

``` text
GUI
 │
 ▼
ORQUESTADOR
 │
 ├── usuario
 ├── permisos
 ├── contraseña
 ├── winrm
 ├── firewall
 └── verificación
```

La GUI será la capa de presentación. Los módulos harán el trabajo real.
El orquestador coordinará los módulos y la verificación comprobará el
estado real.

No se debe volver a concentrar toda la lógica dentro de la GUI.

------------------------------------------------------------------------

## 4. Estados

Los módulos devuelven objetos como:

``` powershell
[PSCustomObject]@{
    Estado  = "SUCCESS"
    Usuario = $NombreUsuario
    Mensaje = "Operacion completada correctamente."
    Codigo  = 0
}
```

### Estados

-   `SUCCESS`: operación completada y verificada.
-   `WARNING`: la operación principal funcionó, pero Windows impuso una
    limitación.
-   `ERROR`: la operación principal no pudo completarse.
-   `SKIPPED`: operación omitida intencionalmente.

Esto permite que la GUI muestre resultados reales por módulo en vez de
un único "ERROR".

------------------------------------------------------------------------

# 5. Módulo Usuario.ps1

## Responsabilidad

Crear y habilitar cuentas locales. No debe administrar grupos, WinRM,
Firewall ni GUI.

## Función

``` powershell
New-LocalSupportUser
```

El verbo `New` representa una operación de creación.

## Flujo

``` text
Nombre + contraseña
       ↓
¿Existe?
 ├─ Sí → resultado controlado
 └─ No → crear → habilitar → verificar → resultado
```

Durante las pruebas se confirmó que Windows puede crear múltiples
cuentas. Se probaron cuentas `testauto1` hasta `testauto10`, por lo que
no se encontró un límite de dos o tres usuarios que explicara los
problemas históricos de la GUI.

------------------------------------------------------------------------

# 6. Módulo Permisos.ps1

## Responsabilidad

Administrar exclusivamente la pertenencia a grupos locales.

## Funciones

``` powershell
Get-LocalGroupBySid
Add-LocalUserPermission
```

## Parámetros reales

La sintaxis comprobada de la función es:

``` text
Add-LocalUserPermission
    [-NombreUsuario] <string>
    [[-UsuarioEstandar] <bool>]
    [[-Administrador] <bool>]
```

Ejemplo:

``` powershell
Add-LocalUserPermission `
    -NombreUsuario "prueba2" `
    -Administrador $false `
    -UsuarioEstandar $true
```

## SID utilizados

``` text
S-1-5-32-544 = Administradores / Administrators
S-1-5-32-545 = Usuarios / Users
```

Se utilizan SID para evitar depender del idioma de Windows.

## Combinaciones

El diseño permite:

-   Usuario estándar solamente.
-   Administrador solamente.
-   Ambos.
-   Ninguno, que debe tratarse como configuración inválida o no
    solicitada según la política.

El módulo fue probado con configuraciones estándar, administrativas,
ambas y ejecuciones repetidas.

------------------------------------------------------------------------

# 7. Módulo Contrasena.ps1

## Versión

**1.1**

## Función

``` powershell
Set-LocalPasswordOptions
```

## Parámetros

``` powershell
-NombreUsuario
-ContrasenaNuncaExpira
-UsuarioPuedeCambiarContrasena
```

Ejemplo:

``` powershell
Set-LocalPasswordOptions `
    -NombreUsuario "prueba2" `
    -ContrasenaNuncaExpira $true `
    -UsuarioPuedeCambiarContrasena $false
```

------------------------------------------------------------------------

# 8. Explicación de las partes principales de Contrasena.ps1

### Parámetros

``` powershell
[Parameter(Mandatory = $true)]
[string]$NombreUsuario
```

Obliga a recibir el nombre de la cuenta y lo trata como texto.

``` powershell
[bool]$ContrasenaNuncaExpira = $false
```

Controla si la contraseña debe expirar.

``` powershell
[bool]$UsuarioPuedeCambiarContrasena = $true
```

Controla si el usuario puede cambiar su contraseña.

### Manejo de errores

``` powershell
try {
    ...
}
catch {
    ...
}
```

Permite capturar excepciones y devolver un resultado estructurado.

### Comprobación de existencia

``` powershell
Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue
```

Busca la cuenta sin convertir un usuario inexistente en un error no
controlado.

### Configuración de expiración

``` powershell
Set-LocalUser `
    -Name $NombreUsuario `
    -PasswordNeverExpires $ContrasenaNuncaExpira `
    -ErrorAction Stop
```

Modifica la política de expiración.

`-ErrorAction Stop` hace que un fallo sea capturable por `catch`.

### Verificación

``` powershell
Get-CimInstance Win32_UserAccount
```

se utiliza para comprobar el estado real de `PasswordExpires`.

La relación es:

``` text
ContrasenaNuncaExpira = $true
        ↓
PasswordExpires = $false
```

y:

``` text
ContrasenaNuncaExpira = $false
        ↓
PasswordExpires = $true
```

### Cambio de contraseña

``` powershell
Set-LocalUser `
    -Name $NombreUsuario `
    -UserMayChangePassword $UsuarioPuedeCambiarContrasena `
    -ErrorAction Stop
```

Configura el permiso de cambio de contraseña.

------------------------------------------------------------------------

# 9. Restricción real de Windows encontrada

Al probar el usuario administrativo `prueba` se solicitó:

``` text
Contraseña nunca expira = TRUE
Usuario puede cambiar contraseña = FALSE
```

Windows respondió:

``` text
No se puede quitar el último administrador
```

El módulo no considera esto un fallo total.

Devuelve:

``` text
Estado = WARNING
Codigo = 7
```

La razón es que la primera operación sí tuvo éxito.

Este es un principio fundamental del proyecto:

> El fallo de una suboperación no debe destruir automáticamente las
> suboperaciones independientes que ya tuvieron éxito.

------------------------------------------------------------------------

# 10. Resultado comprobado de Contrasena.ps1

### Administrador `prueba`

``` text
Expiración desactivada       ✓
Impedir cambio de contraseña ⚠ Windows lo rechazó
Resultado                    WARNING
```

### Usuario estándar `prueba2`

``` text
Expiración desactivada       ✓
Impedir cambio de contraseña  ✓
Resultado                    SUCCESS
Codigo                       0
```

La prueba de `prueba2` confirmó:

``` text
[OK] Configuracion de expiracion aplicada.
[OK] Verificacion de expiracion correcta.
[OK] Configuracion de cambio de contraseña aplicada.
[OK] Verificacion de cambio de contraseña correcta.
```

------------------------------------------------------------------------

# 11. Módulo WinRM.ps1

## Versión

**1.1**

## Función

``` powershell
Enable-LocalWinRM
```

## Responsabilidad

-   Comprobar privilegios administrativos.
-   Comprobar servicio WinRM.
-   Configurar inicio automático.
-   Iniciar WinRM si está detenido.
-   Verificar listener.
-   Detectar Windows PowerShell 5.1.
-   Configurar Windows PowerShell Remoting.
-   Verificar endpoint `Microsoft.PowerShell`.

No administra usuarios ni contraseñas.

------------------------------------------------------------------------

# 12. Explicación de WinRM.ps1

### Identidad actual

``` powershell
[Security.Principal.WindowsIdentity]::GetCurrent()
```

Obtiene la identidad de la sesión actual.

### Comprobación administrativa

``` powershell
$principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
```

Comprueba si la sesión tiene privilegios administrativos.

### Servicio

``` powershell
Get-Service -Name "WinRM"
```

Obtiene el servicio de administración remota de Windows.

### Inicio automático

``` powershell
Set-Service `
    -Name "WinRM" `
    -StartupType Automatic
```

Configura WinRM para iniciarse automáticamente.

### Inicio del servicio

``` powershell
Start-Service -Name "WinRM"
```

Solo se ejecuta cuando WinRM no está iniciado.

### Listener

``` powershell
winrm enumerate winrm/config/listener
```

Permite comprobar que existe un listener.

En el equipo de pruebas se encontró:

``` text
Address   = *
Transport = HTTP
Port      = 5985
Enabled   = true
```

Tener un listener activo no demuestra todavía que otro computador pueda
administrar correctamente este equipo. La conectividad remota real será
una prueba posterior.

### Windows PowerShell 5.1

El proyecto detecta:

``` powershell
Get-Command powershell.exe
```

y utiliza `powershell.exe` para ejecutar la configuración
correspondiente a Windows PowerShell 5.1.

Esto evita depender de que `Enable-PSRemoting` sea ejecutado desde
PowerShell 7.

### Parámetros utilizados

``` text
-NoProfile
-NonInteractive
-Command
```

`-NoProfile` evita cargar perfiles del usuario.

`-NonInteractive` evita que el proceso quede esperando interacción.

`-Command` indica qué instrucción debe ejecutar.

### Endpoint

Se consulta:

``` powershell
Get-PSSessionConfiguration
```

y se busca:

``` text
Microsoft.PowerShell
```

------------------------------------------------------------------------

# 13. Resultado comprobado de WinRM

El módulo fue probado correctamente.

Estado observado:

``` text
WinRM              Running
StartType          Automatic
Listener           HTTP
Puerto             5985
Endpoint           Microsoft.PowerShell
```

Resultado:

``` text
Estado = SUCCESS
Codigo = 0
```

Mensaje:

``` text
WinRM y Windows PowerShell Remoting fueron configurados correctamente.
```

------------------------------------------------------------------------

# 14. PowerShell 7 y Windows PowerShell 5.1

Durante una prueba apareció el aviso:

``` text
PowerShell remoting has been enabled only for PowerShell 6+ configurations
and does not affect Windows PowerShell remoting configurations.
```

Esto mostró que la herramienta debe distinguir entre:

``` text
PowerShell 7+
```

y:

``` text
Windows PowerShell 5.1
```

La solución aplicada consiste en utilizar `powershell.exe` para
configurar y verificar el entorno tradicional de Windows PowerShell.

------------------------------------------------------------------------

# 15. Problema COM / RCW

Durante una versión anterior apareció:

``` text
COM object that has been separated from its underlying RCW cannot be used.
```

El error aparecía después de ejecutar `Enable-PSRemoting`.

La solución arquitectónica fue separar la configuración de Windows
PowerShell 5.1 y no depender de la ejecución problemática de
`Enable-PSRemoting` desde la sesión actual.

No se debe afirmar que el origen interno exacto del RCW quedó demostrado
únicamente con aquella prueba. Sí quedó comprobado que la nueva
implementación terminó correctamente y que WinRM devolvió `SUCCESS`.

------------------------------------------------------------------------

# 16. Evolución de la GUI

Antes de la arquitectura modular se desarrolló una GUI que pasó por
varias versiones:

``` text
V1
V2
V3
V4
V4.2.2
V4.3
V4.4.x
```

La GUI utilizó Runspaces para mantener la interfaz responsiva.

Se encontraron problemas relacionados con:

-   finalización duplicada
-   Timer
-   colas de mensajes
-   resultados estructurados
-   limpieza de Runspaces
-   objetos CIM
-   errores COM/RCW

`V4.2.2` quedó como referencia estable de la GUI anterior.

Posteriormente se decidió no seguir concentrando toda la lógica en la
GUI.

------------------------------------------------------------------------

# 17. Por qué la arquitectura cambió

Una aplicación de TI debe permitir que una función falle sin destruir
las demás.

Ejemplo:

``` text
Usuario       SUCCESS
Permisos      SUCCESS
Contraseña    WARNING
WinRM         SUCCESS
Firewall      ERROR
```

La aplicación debe seguir viva y poder informar cada resultado.

No queremos:

``` text
Firewall ERROR
     ↓
TODO ERROR
```

Queremos:

``` text
Firewall ERROR
     ↓
Solo Firewall falla
     ↓
El resto conserva sus resultados
```

------------------------------------------------------------------------

# 18. Idempotencia

Una operación idempotente puede ejecutarse varias veces sin producir
daños ni configuraciones duplicadas.

Ejemplo:

``` text
Primera ejecución
      ↓
WinRM configurado

Segunda ejecución
      ↓
Detecta que ya está configurado
      ↓
No rompe nada
```

Esto es especialmente importante en automatización.

------------------------------------------------------------------------

# 19. Patrón Change + Verify

Todos los módulos deben seguir:

``` text
CAMBIO
  ↓
VERIFICACIÓN
  ↓
RESULTADO
```

No basta con:

``` text
comando ejecutado = SUCCESS
```

Debe comprobarse:

``` text
estado real del sistema = estado esperado
```

------------------------------------------------------------------------

# 20. Futuro Firewall.ps1

El próximo módulo será:

``` text
Modulos\Firewall.ps1
```

Su responsabilidad será únicamente:

-   identificar el estado del Firewall
-   configurar las reglas necesarias
-   limitar el acceso según la política definida
-   verificar las reglas
-   devolver `SUCCESS`, `WARNING` o `ERROR`

La seguridad debe diseñarse cuidadosamente. Tener WinRM escuchando en
`Address = *` no significa que debamos abrir el puerto
indiscriminadamente hacia Internet.

------------------------------------------------------------------------

# 21. Futuro Verificacion.ps1

Este módulo comprobará el estado final de todo lo preparado.

Ejemplos:

``` text
Usuario existe
Usuario habilitado
Grupo correcto
Contraseña configurada
WinRM Running
WinRM Automatic
Listener disponible
Firewall correcto
```

Su función principal será observar y reportar.

------------------------------------------------------------------------

# 22. Futuro orquestador

El archivo:

``` text
PREPARAR-PC.ps1
```

será el coordinador.

Cargará:

``` powershell
. .\Modulos\Usuario.ps1
. .\Modulos\Permisos.ps1
. .\Modulos\Contrasena.ps1
. .\Modulos\WinRM.ps1
```

y posteriormente:

``` powershell
. .\Modulos\Firewall.ps1
. .\Modulos\Verificacion.ps1
```

Conceptualmente:

``` powershell
$resultados = @()

$resultados += New-LocalSupportUser ...
$resultados += Add-LocalUserPermission ...
$resultados += Set-LocalPasswordOptions ...
$resultados += Enable-LocalWinRM ...
```

Después podrá procesarlos individualmente.

------------------------------------------------------------------------

# 23. Futuro de la GUI

La GUI permitirá introducir:

``` text
Usuario
Contraseña
Privilegios
Opciones de contraseña
WinRM
Firewall
```

Y mostrará algo parecido a:

``` text
Preparando PC...

✓ Usuario
✓ Permisos
⚠ Contraseña
✓ WinRM
✗ Firewall

Resultado:
Preparación completada con advertencias.
```

La barra de progreso y los mensajes visibles serán responsabilidad de la
interfaz, no de cada módulo.

------------------------------------------------------------------------

# 24. Seguridad

Las contraseñas `prueba` utilizadas durante el laboratorio son
exclusivamente de prueba.

No deben quedar hardcodeadas en una herramienta productiva.

En una implementación real deben evaluarse mecanismos como:

-   entrada segura
-   credenciales protegidas
-   Credential Manager
-   secretos externos
-   políticas de dominio
-   Active Directory o Entra ID cuando corresponda

Para WinRM:

``` text
HTTP 5985
```

no debe exponerse indiscriminadamente a Internet.

Una arquitectura real debería considerar:

-   red de administración
-   VPN
-   restricciones de origen en Firewall
-   HTTPS/certificados cuando corresponda
-   políticas de seguridad
-   segmentación de red

------------------------------------------------------------------------

# 25. Pruebas realizadas

  Módulo       Prueba                          Resultado
  ------------ ------------------------------- --------------------
  Usuario      Crear usuario                   ✓
  Usuario      Usuario existente               ✓
  Usuario      Múltiples cuentas               ✓
  Permisos     Usuario estándar                ✓
  Permisos     Administrador                   ✓
  Permisos     Ambos                           ✓
  Permisos     Ejecución repetida              ✓
  Contraseña   Nunca expira                    ✓
  Contraseña   Estándar no cambia contraseña   ✓
  Contraseña   Último administrador            ⚠ WARNING esperado
  WinRM        Servicio                        ✓
  WinRM        Automatic                       ✓
  WinRM        Listener                        ✓
  WinRM        PowerShell 5.1                  ✓
  WinRM        Microsoft.PowerShell            ✓

------------------------------------------------------------------------

# 26. Errores históricos

## Error: Markdown dentro de `.ps1`

**Problema:** se incluyeron delimitadores Markdown dentro del script.

**Solución:** los archivos `.ps1` contienen solo PowerShell; Markdown
solo en documentación.

## Error: descripción demasiado larga

**Problema:** `New-LocalUser` rechazó una descripción demasiado larga.

**Solución:** utilizar una descripción corta, por ejemplo:

``` powershell
"Cuenta de prueba"
```

## Error: continuar después de una excepción

**Problema:** una creación fallida podía ser seguida por operaciones
sobre un usuario que no existía.

**Solución:**

``` powershell
-ErrorAction Stop
```

y `try/catch`.

## Error: nombres de grupos dependientes del idioma

**Problema:** `Administradores` no existe con ese nombre en todos los
Windows.

**Solución:** localizar grupos por SID.

``` text
S-1-5-32-544
S-1-5-32-545
```

## Error: verificación de PasswordNeverExpires

**Problema:** la propiedad consultada mediante `Get-LocalUser` no fue
suficiente para la verificación utilizada.

**Solución:** verificar mediante `Win32_UserAccount.PasswordExpires`.

## Error: parámetros incorrectos

**Problema:**

``` text
-EsAdministrador
-EsUsuarioEstandar
```

no corresponden a la función actual.

**Solución:**

``` text
-Administrador
-UsuarioEstandar
```

Consultar siempre:

``` powershell
Get-Command Add-LocalUserPermission -Syntax
```

## Error: último administrador

**Problema:** Windows rechazó impedir el cambio de contraseña para el
último administrador.

**Solución:** devolver `WARNING` y conservar las configuraciones que sí
fueron aplicadas.

## Error: RCW / COM

**Problema:**

``` text
COM object that has been separated from its underlying RCW cannot be used.
```

**Solución aplicada:** separar la configuración de Windows PowerShell
5.1 y no depender de la ejecución problemática de `Enable-PSRemoting`
desde la sesión actual.

------------------------------------------------------------------------

# 27. Convenciones de desarrollo

Las funciones deben utilizar verbos aprobados por PowerShell.

Ejemplos:

``` powershell
New-LocalSupportUser
Add-LocalUserPermission
Set-LocalPasswordOptions
Enable-LocalWinRM
Get-LocalGroupBySid
```

Para comprobar una función:

``` powershell
Get-Command NombreFuncion
```

Para consultar su sintaxis:

``` powershell
Get-Command NombreFuncion -Syntax
```

------------------------------------------------------------------------

# 28. Metodología de desarrollo

Cada módulo debe pasar por:

``` text
1. Crear
2. Cargar
3. Verificar función
4. Consultar sintaxis
5. Prueba positiva
6. Prueba negativa
7. Verificación
8. Documentar errores
9. Aprobar módulo
10. Integrar
```

No se debe integrar un módulo sin probarlo independientemente.

------------------------------------------------------------------------

# 29. Estado actual

``` text
Usuario       ✓ COMPLETADO
Permisos      ✓ COMPLETADO
Contraseña    ✓ COMPLETADO
WinRM         ✓ COMPLETADO

Firewall      → SIGUIENTE
Verificación  → PENDIENTE
Orquestador   → PENDIENTE
GUI           → PENDIENTE
Pruebas final → PENDIENTE
```

------------------------------------------------------------------------

# 30. Orden recomendado de construcción

``` text
Usuario
   ↓
Permisos
   ↓
Contraseña
   ↓
WinRM
   ↓
Firewall
   ↓
Verificación
   ↓
Orquestador
   ↓
GUI
   ↓
Pruebas integrales
```

La GUI se deja para el final porque primero necesitamos que la lógica
funcione correctamente por separado.

------------------------------------------------------------------------

# 31. Regla de oro

``` text
UNA RESPONSABILIDAD
        ↓
UN MÓDULO
        ↓
UNA FUNCIÓN
        ↓
MANEJO DE ERRORES
        ↓
VERIFICACIÓN
        ↓
RESULTADO ESTRUCTURADO
```

Después:

``` text
MÓDULOS
   ↓
ORQUESTADOR
   ↓
GUI
```

Esta separación permite cambiar la interfaz sin reescribir la lógica y
corregir un módulo sin romper los demás.

------------------------------------------------------------------------

# 32. Conclusión

El proyecto evolucionó desde un script monolítico hacia una arquitectura
modular porque las pruebas reales demostraron que la segunda
arquitectura es más mantenible y resistente a errores.

La meta no es simplemente ejecutar comandos de PowerShell.

La herramienta debe poder responder:

``` text
¿Qué intentó hacer?
¿Qué consiguió hacer?
¿Qué no pudo hacer?
¿Por qué no pudo hacerlo?
¿Qué estado quedó realmente configurado?
```

Esa información permitirá que la futura GUI presente resultados claros y
que un técnico pueda diagnosticar rápidamente un equipo.

------------------------------------------------------------------------

# 33. Próximo módulo

El siguiente componente de desarrollo es:

``` text
Modulos\Firewall.ps1
```

Debe construirse y probarse independientemente antes de conectarlo al
orquestador o a la GUI.
