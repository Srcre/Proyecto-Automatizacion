# ============================================================
# PROYECTO: AUTOMATIZACION
# ARCHIVO: PREPARAR-PC.ps1
# VERSION: 1.2
#
# DESCRIPCION:
# Orquestador principal del proyecto.
#
# Este archivo carga, ejecuta y recopila los resultados
# de los modulos independientes.
#
# Tambien integra el modulo Logs.ps1 para registrar
# cada resultado de ejecucion.
#
# MODULOS:
#   1. Usuario
#   2. Permisos
#   3. Contrasena
#   4. Firewall
#   5. WinRM
#   6. Verificacion
#   7. Logs
#
# REGLA PRINCIPAL:
# Un error en un modulo no debe detener la ejecucion
# de los demas modulos.
#
# REGLA DE LOGS:
# Un error en Logs.ps1 tampoco debe detener la ejecucion
# de los demas modulos.
# ============================================================


# ============================================================
# 1. CONFIGURACION
# ============================================================

$Configuracion = @{
    NombreUsuario = "prueba2"

    Contrasena = "prueba"

    UsuarioEstandar = $true

    Administrador = $false

    ContrasenaNuncaExpira = $true

    UsuarioPuedeCambiarContrasena = $false
}


# ============================================================
# 2. RUTA DE LOS MODULOS
# ============================================================

$RutaModulos = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath "Modulos"


# ============================================================
# 3. LISTA DE RESULTADOS
# ============================================================

$resultados = @()


# ============================================================
# 4. FUNCION: VERIFICAR PRIVILEGIOS ADMINISTRATIVOS
# ============================================================

function Test-LocalAdministrator {

    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object Security.Principal.WindowsPrincipal(
        $identidad
    )

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


# ============================================================
# 5. FUNCION: REGISTRAR RESULTADO DEL MODULO
# ============================================================

function Add-ModuleResult {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NombreModulo,

        [Parameter(Mandatory = $true)]
        $Resultado
    )

    $script:resultados += [PSCustomObject]@{
        Modulo  = $NombreModulo
        Estado  = $Resultado.Estado
        Usuario = $Resultado.Usuario
        Mensaje = $Resultado.Mensaje
        Codigo  = $Resultado.Codigo
    }

    Write-Host ""
    Write-Host "[INFO] Resultado modulo '$NombreModulo': $($Resultado.Estado)"
}


# ============================================================
# 6. FUNCION: REGISTRAR LOG DE FORMA SEGURA
# ============================================================

function Write-PreparationLog {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NombreModulo,

        [Parameter(Mandatory = $true)]
        [string]$Estado,

        [string]$NombreUsuario = "",

        [int]$Codigo = 0,

        [Parameter(Mandatory = $true)]
        [string]$Mensaje
    )

    try {

        if (-not (Get-Command Write-LocalPreparationLog -ErrorAction SilentlyContinue)) {

            Write-Host "[WARNING] El modulo Logs no esta disponible."
            return
        }

        $resultadoLog = Write-LocalPreparationLog `
            -NombreModulo $NombreModulo `
            -Estado $Estado `
            -NombreUsuario $NombreUsuario `
            -Codigo $Codigo `
            -Mensaje $Mensaje

        if ($resultadoLog.Estado -eq "SUCCESS") {

            Write-Host "[OK] Registro guardado en Logs."
        }
        else {

            Write-Host "[WARNING] No fue posible guardar el registro."
            Write-Host "[WARNING] $($resultadoLog.Mensaje)"
        }
    }
    catch {

        Write-Host "[WARNING] Error al registrar el log."
        Write-Host "[WARNING] $($_.Exception.Message)"
    }
}


# ============================================================
# 7. CARGAR MODULO LOGS
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO LOGS"
Write-Host "==============================================="

$logsDisponible = $false

try {

    $rutaLogs = Join-Path `
        $RutaModulos `
        "Logs.ps1"

    if (-not (Test-Path $rutaLogs)) {

        throw "No fue posible encontrar el modulo Logs.ps1."
    }

    . $rutaLogs

    if (-not (Get-Command Write-LocalPreparationLog -ErrorAction SilentlyContinue)) {

        throw "La funcion Write-LocalPreparationLog no fue encontrada."
    }

    $logsDisponible = $true

    Write-Host "[OK] Modulo Logs cargado."
}
catch {

    Write-Host "[WARNING] No fue posible cargar el modulo Logs."
    Write-Host "[WARNING] $($_.Exception.Message)"
    Write-Host "[WARNING] La preparacion continuara sin registro de Logs."
}


# ============================================================
# 8. ENCABEZADO
# ============================================================

Clear-Host

Write-Host "==============================================="
Write-Host "       PREPARAR-PC - AUTOMATIZACION"
Write-Host "==============================================="
Write-Host ""

Write-Host "[INFO] Usuario configurado: $($Configuracion.NombreUsuario)"
Write-Host "[INFO] Usuario estandar: $($Configuracion.UsuarioEstandar)"
Write-Host "[INFO] Administrador: $($Configuracion.Administrador)"
Write-Host "[INFO] Contraseña nunca expira: $($Configuracion.ContrasenaNuncaExpira)"
Write-Host "[INFO] Usuario puede cambiar contraseña: $($Configuracion.UsuarioPuedeCambiarContrasena)"

if ($logsDisponible) {

    Write-Host "[OK] Sistema de Logs disponible."
}
else {

    Write-Host "[WARNING] Sistema de Logs no disponible."
}


# ============================================================
# 9. VERIFICAR PRIVILEGIOS ADMINISTRATIVOS
# ============================================================

Write-Host ""
Write-Host "[INFO] Verificando privilegios administrativos..."

if (-not (Test-LocalAdministrator)) {

    Write-Host "[ERROR] La consola no tiene privilegios administrativos."
    Write-Host "[ERROR] Ejecute PowerShell como Administrador."

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "PREPARAR-PC" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 1 `
            -Mensaje "La consola no tiene privilegios administrativos."
    }

    exit 1
}

Write-Host "[OK] La consola tiene privilegios administrativos."


# ============================================================
# 10. MODULO USUARIO
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO USUARIO"
Write-Host "==============================================="

try {

    $rutaUsuario = Join-Path `
        $RutaModulos `
        "usuario.ps1"

    if (-not (Test-Path $rutaUsuario)) {

        throw "No fue posible encontrar el modulo Usuario.ps1."
    }

    . $rutaUsuario

    if (-not (Get-Command New-LocalSupportUser -ErrorAction SilentlyContinue)) {

        throw "La funcion New-LocalSupportUser no fue encontrada."
    }

    Write-Host "[OK] Modulo Usuario cargado."

    $resultadoUsuario = New-LocalSupportUser `
        -NombreUsuario $Configuracion.NombreUsuario `
        -Contrasena $Configuracion.Contrasena

    Add-ModuleResult `
        -NombreModulo "Usuario" `
        -Resultado $resultadoUsuario

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Usuario" `
            -Estado $resultadoUsuario.Estado `
            -NombreUsuario $resultadoUsuario.Usuario `
            -Codigo $resultadoUsuario.Codigo `
            -Mensaje $resultadoUsuario.Mensaje
    }
}
catch {

    Write-Host "[ERROR] Error en el modulo Usuario."
    Write-Host "[ERROR] $($_.Exception.Message)"

    $script:resultados += [PSCustomObject]@{
        Modulo  = "Usuario"
        Estado  = "ERROR"
        Usuario = $Configuracion.NombreUsuario
        Mensaje = $_.Exception.Message
        Codigo  = 900
    }

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Usuario" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 900 `
            -Mensaje $_.Exception.Message
    }
}


# ============================================================
# 11. MODULO PERMISOS
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO PERMISOS"
Write-Host "==============================================="

try {

    $rutaPermisos = Join-Path `
        $RutaModulos `
        "permisos.ps1"

    if (-not (Test-Path $rutaPermisos)) {

        throw "No fue posible encontrar el modulo Permisos.ps1."
    }

    . $rutaPermisos

    if (-not (Get-Command Add-LocalUserPermission -ErrorAction SilentlyContinue)) {

        throw "La funcion Add-LocalUserPermission no fue encontrada."
    }

    Write-Host "[OK] Modulo Permisos cargado."

    $resultadoPermisos = Add-LocalUserPermission `
        -NombreUsuario $Configuracion.NombreUsuario `
        -UsuarioEstandar $Configuracion.UsuarioEstandar `
        -Administrador $Configuracion.Administrador

    Add-ModuleResult `
        -NombreModulo "Permisos" `
        -Resultado $resultadoPermisos

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Permisos" `
            -Estado $resultadoPermisos.Estado `
            -NombreUsuario $resultadoPermisos.Usuario `
            -Codigo $resultadoPermisos.Codigo `
            -Mensaje $resultadoPermisos.Mensaje
    }
}
catch {

    Write-Host "[ERROR] Error en el modulo Permisos."
    Write-Host "[ERROR] $($_.Exception.Message)"

    $script:resultados += [PSCustomObject]@{
        Modulo  = "Permisos"
        Estado  = "ERROR"
        Usuario = $Configuracion.NombreUsuario
        Mensaje = $_.Exception.Message
        Codigo  = 901
    }

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Permisos" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 901 `
            -Mensaje $_.Exception.Message
    }
}


# ============================================================
# 12. MODULO CONTRASENA
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO CONTRASEÑA"
Write-Host "==============================================="

try {

    $rutaContrasena = Join-Path `
        $RutaModulos `
        "contraseña.ps1"

    if (-not (Test-Path $rutaContrasena)) {

        throw "No fue posible encontrar el modulo contraseña.ps1."
    }

    . $rutaContrasena

    if (-not (Get-Command Set-LocalPasswordOptions -ErrorAction SilentlyContinue)) {

        throw "La funcion Set-LocalPasswordOptions no fue encontrada."
    }

    Write-Host "[OK] Modulo Contrasena cargado."

    $resultadoContrasena = Set-LocalPasswordOptions `
        -NombreUsuario $Configuracion.NombreUsuario `
        -ContrasenaNuncaExpira $Configuracion.ContrasenaNuncaExpira `
        -UsuarioPuedeCambiarContrasena $Configuracion.UsuarioPuedeCambiarContrasena

    Add-ModuleResult `
        -NombreModulo "Contrasena" `
        -Resultado $resultadoContrasena

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Contrasena" `
            -Estado $resultadoContrasena.Estado `
            -NombreUsuario $resultadoContrasena.Usuario `
            -Codigo $resultadoContrasena.Codigo `
            -Mensaje $resultadoContrasena.Mensaje
    }
}
catch {

    Write-Host "[ERROR] Error en el modulo Contrasena."
    Write-Host "[ERROR] $($_.Exception.Message)"

    $script:resultados += [PSCustomObject]@{
        Modulo  = "Contrasena"
        Estado  = "ERROR"
        Usuario = $Configuracion.NombreUsuario
        Mensaje = $_.Exception.Message
        Codigo  = 902
    }

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Contrasena" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 902 `
            -Mensaje $_.Exception.Message
    }
}


# ============================================================
# 13. MODULO FIREWALL
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO FIREWALL"
Write-Host "==============================================="

try {

    $rutaFirewall = Join-Path `
        $RutaModulos `
        "firewall.ps1"

    if (-not (Test-Path $rutaFirewall)) {

        throw "No fue posible encontrar el modulo Firewall.ps1."
    }

    . $rutaFirewall

    if (-not (Get-Command Enable-LocalFirewallWinRM -ErrorAction SilentlyContinue)) {

        throw "La funcion Enable-LocalFirewallWinRM no fue encontrada."
    }

    Write-Host "[OK] Modulo Firewall cargado."

    $resultadoFirewall = Enable-LocalFirewallWinRM

    Add-ModuleResult `
        -NombreModulo "Firewall" `
        -Resultado $resultadoFirewall

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Firewall" `
            -Estado $resultadoFirewall.Estado `
            -NombreUsuario $resultadoFirewall.Usuario `
            -Codigo $resultadoFirewall.Codigo `
            -Mensaje $resultadoFirewall.Mensaje
    }
}
catch {

    Write-Host "[ERROR] Error en el modulo Firewall."
    Write-Host "[ERROR] $($_.Exception.Message)"

    $script:resultados += [PSCustomObject]@{
        Modulo  = "Firewall"
        Estado  = "ERROR"
        Usuario = $Configuracion.NombreUsuario
        Mensaje = $_.Exception.Message
        Codigo  = 903
    }

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Firewall" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 903 `
            -Mensaje $_.Exception.Message
    }
}


# ============================================================
# 14. MODULO WINRM
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO WINRM"
Write-Host "==============================================="

try {

    $rutaWinRM = Join-Path `
        $RutaModulos `
        "winrm.ps1"

    if (-not (Test-Path $rutaWinRM)) {

        throw "No fue posible encontrar el modulo WinRM.ps1."
    }

    . $rutaWinRM

    if (-not (Get-Command Enable-LocalWinRM -ErrorAction SilentlyContinue)) {

        throw "La funcion Enable-LocalWinRM no fue encontrada."
    }

    Write-Host "[OK] Modulo WinRM cargado."

    $resultadoWinRM = Enable-LocalWinRM

    Add-ModuleResult `
        -NombreModulo "WinRM" `
        -Resultado $resultadoWinRM

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "WinRM" `
            -Estado $resultadoWinRM.Estado `
            -NombreUsuario $resultadoWinRM.Usuario `
            -Codigo $resultadoWinRM.Codigo `
            -Mensaje $resultadoWinRM.Mensaje
    }
}
catch {

    Write-Host "[ERROR] Error en el modulo WinRM."
    Write-Host "[ERROR] $($_.Exception.Message)"

    $script:resultados += [PSCustomObject]@{
        Modulo  = "WinRM"
        Estado  = "ERROR"
        Usuario = $Configuracion.NombreUsuario
        Mensaje = $_.Exception.Message
        Codigo  = 904
    }

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "WinRM" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 904 `
            -Mensaje $_.Exception.Message
    }
}


# ============================================================
# 15. MODULO VERIFICACION
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[INFO] MODULO VERIFICACION"
Write-Host "==============================================="

try {

    $rutaVerificacion = Join-Path `
        $RutaModulos `
        "verificacion.ps1"

    if (-not (Test-Path $rutaVerificacion)) {

        throw "No fue posible encontrar el modulo Verificacion.ps1."
    }

    . $rutaVerificacion

    if (-not (Get-Command Test-LocalComputerConfiguration -ErrorAction SilentlyContinue)) {

        throw "La funcion Test-LocalComputerConfiguration no fue encontrada."
    }

    Write-Host "[OK] Modulo Verificacion cargado."

    $resultadoVerificacion = Test-LocalComputerConfiguration `
        -NombreUsuario $Configuracion.NombreUsuario `
        -UsuarioEstandar $Configuracion.UsuarioEstandar `
        -Administrador $Configuracion.Administrador `
        -ContrasenaNuncaExpira $Configuracion.ContrasenaNuncaExpira `
        -UsuarioPuedeCambiarContrasena $Configuracion.UsuarioPuedeCambiarContrasena

    Add-ModuleResult `
        -NombreModulo "Verificacion" `
        -Resultado $resultadoVerificacion

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Verificacion" `
            -Estado $resultadoVerificacion.Estado `
            -NombreUsuario $resultadoVerificacion.Usuario `
            -Codigo $resultadoVerificacion.Codigo `
            -Mensaje $resultadoVerificacion.Mensaje
    }
}
catch {

    Write-Host "[ERROR] Error en el modulo Verificacion."
    Write-Host "[ERROR] $($_.Exception.Message)"

    $script:resultados += [PSCustomObject]@{
        Modulo  = "Verificacion"
        Estado  = "ERROR"
        Usuario = $Configuracion.NombreUsuario
        Mensaje = $_.Exception.Message
        Codigo  = 905
    }

    if ($logsDisponible) {

        Write-PreparationLog `
            -NombreModulo "Verificacion" `
            -Estado "ERROR" `
            -NombreUsuario $Configuracion.NombreUsuario `
            -Codigo 905 `
            -Mensaje $_.Exception.Message
    }
}


# ============================================================
# 16. RESUMEN FINAL
# ============================================================

Write-Host ""
Write-Host ""
Write-Host "==============================================="
Write-Host "          RESUMEN PREPARAR-PC"
Write-Host "==============================================="

$script:resultados |
    Format-Table `
        Modulo,
        Estado,
        Codigo,
        Mensaje `
        -AutoSize


# ============================================================
# 17. DETERMINAR RESULTADO GLOBAL
# ============================================================

$cantidadSuccess = @(
    $script:resultados |
    Where-Object {
        $_.Estado -eq "SUCCESS"
    }
).Count

$cantidadWarning = @(
    $script:resultados |
    Where-Object {
        $_.Estado -eq "WARNING"
    }
).Count

$cantidadError = @(
    $script:resultados |
    Where-Object {
        $_.Estado -eq "ERROR"
    }
).Count


Write-Host ""
Write-Host "[OK] Modulos correctos : $cantidadSuccess"
Write-Host "[WARNING] Advertencias  : $cantidadWarning"
Write-Host "[ERROR] Errores         : $cantidadError"


# ============================================================
# 18. RESULTADO GLOBAL
# ============================================================

if ($cantidadError -gt 0) {

    $estadoGlobal = "ERROR"
    $codigoGlobal = 100

    $mensajeGlobal = `
        "La preparacion del equipo termino con $cantidadError error(es)."
}
elseif ($cantidadWarning -gt 0) {

    $estadoGlobal = "WARNING"
    $codigoGlobal = 101

    $mensajeGlobal = `
        "La preparacion del equipo termino con $cantidadWarning advertencia(s)."
}
else {

    $estadoGlobal = "SUCCESS"
    $codigoGlobal = 0

    $mensajeGlobal = `
        "La preparacion del equipo finalizo correctamente."
}


# ============================================================
# 19. GUARDAR RESULTADO GLOBAL EN LOGS
# ============================================================

if ($logsDisponible) {

    Write-PreparationLog `
        -NombreModulo "PREPARAR-PC" `
        -Estado $estadoGlobal `
        -NombreUsuario $Configuracion.NombreUsuario `
        -Codigo $codigoGlobal `
        -Mensaje $mensajeGlobal
}


# ============================================================
# 20. RESULTADO FINAL
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "[RESULTADO] $estadoGlobal"
Write-Host "[RESULTADO] $mensajeGlobal"
Write-Host "==============================================="


# ============================================================
# 21. DEVOLVER RESULTADO
# ============================================================

[PSCustomObject]@{
    Estado     = $estadoGlobal
    Usuario    = $Configuracion.NombreUsuario
    Mensaje    = $mensajeGlobal
    Codigo     = $codigoGlobal
    Resultados = $script:resultados
}