# ============================================================
# MODULO: PERMISOS
# VERSION: 1.0
# DESCRIPCION:
#   Gestiona la pertenencia de un usuario a los grupos locales
#   Usuarios y Administradores.
#
# RESPONSABILIDAD:
#   Este modulo SOLO gestiona grupos y permisos.
#
# NO CONFIGURA:
#   - Creacion de usuarios
#   - Contraseñas
#   - WinRM
#   - Firewall
#   - GUI
# ============================================================

# Comprension de codigo

# como primer apartado tenemos una función que agrupa
# como su nombre lo indica, la funcion agrupa los grupos que tiene nativamente windows (las que usamos son Usuarios/Administradores)
# pero en este caso no se busca por el nombre, se busca por el SID (que vendria siendo una ID que tienen los usuarios de windows)
# como son solo dos usuarios Usuario/Administrador se busca la SID de estos dos con un try y una condicional que evalua si existe Usuario/Administrador
function Get-LocalGroupBySid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sid
    )
    try {
        $grupo = Get-LocalGroup |
            Where-Object { $_.SID.Value -eq $Sid }
        if ($null -eq $grupo) {
            throw "No se encontro el grupo local con SID '$Sid'."
        }
        return $grupo
    }
    catch {
        throw
    }
}

# Esta función es la encargada de agregar los usuarios dentro de la carpeta Usuarios dentro del programa 
# "administrador de equipos" que tiene windows, además de eso no solo los agrega, tambien les da el privilegio (si es Usuario/Administrador)
# en esta función se trabaja como true/false, ya que al momento de agregar a un usuario se debe de elegir si solo es usuario, administrador o ambos
function Add-LocalUserPermission {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NombreUsuario,
        [bool]$UsuarioEstandar = $false,
        [bool]$Administrador = $false
    )
    try {
        Write-Host "[INFO] Iniciando configuracion de permisos para '$NombreUsuario'..."
        # --------------------------------------------------------
        # 1. Validar que se haya seleccionado al menos un permiso
        # --------------------------------------------------------
        if (-not $UsuarioEstandar -and -not $Administrador) {
            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $NombreUsuario
                Mensaje = "Debe seleccionarse Usuario estándar, Administrador o ambos."
                Codigo  = 1
            }
        }
        # --------------------------------------------------------
        # 2. Verificar que el usuario exista
        # --------------------------------------------------------
        $usuario = Get-LocalUser `
            -Name $NombreUsuario `
            -ErrorAction SilentlyContinue
        if ($null -eq $usuario) {
            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $NombreUsuario
                Mensaje = "El usuario '$NombreUsuario' no existe."
                Codigo  = 2
            }
        }
        # --------------------------------------------------------
        # 3. Obtener grupos mediante SID (ID con el que trabaja Windows)
        # --------------------------------------------------------
        # S-1-5-32-545 = Users / Usuarios
        $grupoUsuarios = Get-LocalGroupBySid `
            -Sid "S-1-5-32-545"
        # S-1-5-32-544 = Administrators / Administradores
        $grupoAdministradores = Get-LocalGroupBySid `
            -Sid "S-1-5-32-544"
        # --------------------------------------------------------
        # 4. Configurar grupo Usuarios
        # --------------------------------------------------------
        if ($UsuarioEstandar) {
            Write-Host "[INFO] Agregando '$NombreUsuario' al grupo '$($grupoUsuarios.Name)'..."
            $miembro = Get-LocalGroupMember `
                -Group $grupoUsuarios.Name `
                -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "\\$([regex]::Escape($NombreUsuario))$" }
            if ($null -eq $miembro) {
                Add-LocalGroupMember `
                    -Group $grupoUsuarios.Name `
                    -Member $NombreUsuario `
                    -ErrorAction Stop
                Write-Host "[OK] Usuario agregado a '$($grupoUsuarios.Name)'."
            }
            else {
                Write-Host "[INFO] El usuario ya pertenece a '$($grupoUsuarios.Name)'."
            }
        }
        # --------------------------------------------------------
        # 5. Configurar grupo Administradores
        # --------------------------------------------------------
        if ($Administrador) {
            Write-Host "[INFO] Agregando '$NombreUsuario' al grupo '$($grupoAdministradores.Name)'..."
            $miembro = Get-LocalGroupMember `
                -Group $grupoAdministradores.Name `
                -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "\\$([regex]::Escape($NombreUsuario))$" }
            if ($null -eq $miembro) {
                Add-LocalGroupMember `
                    -Group $grupoAdministradores.Name `
                    -Member $NombreUsuario `
                    -ErrorAction Stop
                Write-Host "[OK] Usuario agregado a '$($grupoAdministradores.Name)'."
            }
            else {
                Write-Host "[INFO] El usuario ya pertenece a '$($grupoAdministradores.Name)'."
            }
        }
        # --------------------------------------------------------
        # 6. Verificacion
        # --------------------------------------------------------
        $errores = @()
        if ($UsuarioEstandar) {
            $verificarUsuarios = Get-LocalGroupMember `
                -Group $grupoUsuarios.Name `
                -ErrorAction Stop |
                Where-Object { $_.Name -match "\\$([regex]::Escape($NombreUsuario))$" }
            if ($null -eq $verificarUsuarios) {
                $errores += "No fue posible verificar la pertenencia al grupo Usuarios."
            }
        }
        if ($Administrador) {
            $verificarAdministradores = Get-LocalGroupMember `
                -Group $grupoAdministradores.Name `
                -ErrorAction Stop |
                Where-Object { $_.Name -match "\\$([regex]::Escape($NombreUsuario))$" }
            if ($null -eq $verificarAdministradores) {
                $errores += "No fue posible verificar la pertenencia al grupo Administradores."
            }
        }
        if ($errores.Count -gt 0) {
            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $NombreUsuario
                Mensaje = ($errores -join " ")
                Codigo  = 3
            }
        }
        # --------------------------------------------------------
        # 7. Resultado exitoso
        # --------------------------------------------------------
        $permisos = @()
        if ($UsuarioEstandar) {
            $permisos += "Usuario estándar"
        }
        if ($Administrador) {
            $permisos += "Administrador"
        }
        $descripcionPermisos = $permisos -join " + "
        Write-Host "[OK] Permisos configurados correctamente: $descripcionPermisos."
        return [PSCustomObject]@{
            Estado  = "SUCCESS"
            Usuario = $NombreUsuario
            Mensaje = "Permisos configurados correctamente: $descripcionPermisos."
            Codigo  = 0
        }
    }
    catch {
        Write-Host "[ERROR] No fue posible configurar los permisos."
        Write-Host "[ERROR] $($_.Exception.Message)"
        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = $NombreUsuario
            Mensaje = $_.Exception.Message
            Codigo  = 4
        }
    }
}