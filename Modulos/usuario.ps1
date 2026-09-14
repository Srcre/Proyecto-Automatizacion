# ============================================================
# MODULO: USUARIO
# VERSION: 1.0
# DESCRIPCION:
#   Crea y habilita una cuenta local de Windows.
#
# RESPONSABILIDAD:
#   Este modulo SOLO gestiona la creacion del usuario.
#
# NO CONFIGURA:
#   - Grupos
#   - Administradores
#   - Contraseña nunca expira
#   - WinRM
#   - Firewall
#   - GUI
# ============================================================

function New-LocalSupportUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NombreUsuario,
        [Parameter(Mandatory = $true)]
        [string]$Contrasena
    )
    try {
        Write-Host "[INFO] Iniciando creacion del usuario '$NombreUsuario'..."
        # --------------------------------------------------------
        # 1. Comprobar si el usuario ya existe
        # --------------------------------------------------------
        $usuarioExistente = Get-LocalUser `
            -Name $NombreUsuario `
            -ErrorAction SilentlyContinue
        if ($null -ne $usuarioExistente) {
            Write-Host "[ERROR] El usuario '$NombreUsuario' ya existe."
            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $NombreUsuario
                Mensaje = "El usuario ya existe."
                Codigo  = 1
            }
        }
        # --------------------------------------------------------
        # 2. Convertir contraseña a SecureString
        # --------------------------------------------------------
        $passwordSecure = ConvertTo-SecureString `
            $Contrasena `
            -AsPlainText `
            -Force
        # --------------------------------------------------------
        # 3. Crear usuario
        # --------------------------------------------------------
        Write-Host "[INFO] Creando usuario..."
        New-LocalUser `
            -Name $NombreUsuario `
            -Password $passwordSecure `
            -Description "Cuenta creada por herramienta TI" `
            -ErrorAction Stop
        # --------------------------------------------------------
        # 4. Habilitar usuario
        # --------------------------------------------------------
        Write-Host "[INFO] Habilitando usuario..."
        Enable-LocalUser `
            -Name $NombreUsuario `
            -ErrorAction Stop
        # --------------------------------------------------------
        # 5. Resultado exitoso
        # --------------------------------------------------------
        Write-Host "[OK] Usuario '$NombreUsuario' creado correctamente."
        return [PSCustomObject]@{
            Estado  = "SUCCESS"
            Usuario = $NombreUsuario
            Mensaje = "Usuario creado y habilitado correctamente."
            Codigo  = 0
        }
    }
    catch {
        Write-Host "[ERROR] No fue posible crear el usuario."
        Write-Host "[ERROR] $($_.Exception.Message)"
        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = $NombreUsuario
            Mensaje = $_.Exception.Message
            Codigo  = 2
        }
    }
}