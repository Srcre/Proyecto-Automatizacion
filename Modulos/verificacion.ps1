# ============================================================
# MODULO: VERIFICACION
# VERSION: 1.2
#
# DESCRIPCION:
# Verifica el estado real de la configuracion del equipo.
#
# Este modulo NO modifica configuraciones.
# Solo consulta y compara el estado actual contra el estado
# esperado indicado por el tecnico.
#
# COMPONENTES VERIFICADOS:
#   1. Privilegios administrativos
#   2. Usuario
#   3. Estado de la cuenta
#   4. Grupos / permisos
#   5. Configuracion de contraseña
#   6. Servicio WinRM
#   7. Inicio automatico de WinRM
#   8. Listener WinRM HTTP 5985
#   9. Endpoint Microsoft.PowerShell
#  10. Perfil de red
#  11. Firewall
#  12. Regla WinRM TCP 5985
#
# IMPORTANTE:
# No utiliza Get-PSSessionConfiguration debido al error RCW
# detectado en este entorno.
#
# RESULTADO:
# Devuelve un objeto estructurado con:
#   Estado
#   Usuario
#   Mensaje
#   Codigo
#   Verificaciones
# ============================================================


# ============================================================
# FUNCION AUXILIAR
# OBTENER GRUPO LOCAL MEDIANTE SID
# ============================================================

function Get-VerificationLocalGroupBySid {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Sid
    )

    try {

        $grupo = Get-LocalGroup |
            Where-Object {
                $_.SID.Value -eq $Sid
            } |
            Select-Object -First 1

        return $grupo
    }
    catch {

        return $null
    }
}


# ============================================================
# FUNCION PRINCIPAL
# ============================================================

function Test-LocalComputerConfiguration {

    param(

        # ----------------------------------------------------
        # USUARIO
        # ----------------------------------------------------

        [Parameter(Mandatory = $true)]
        [string]$NombreUsuario,


        # ----------------------------------------------------
        # PERMISOS ESPERADOS
        # ----------------------------------------------------

        [bool]$UsuarioEstandar = $false,

        [bool]$Administrador = $false,


        # ----------------------------------------------------
        # CONTRASEÑA ESPERADA
        # ----------------------------------------------------

        [bool]$ContrasenaNuncaExpira = $false,

        [bool]$UsuarioPuedeCambiarContrasena = $true
    )


    # ========================================================
    # VARIABLES INTERNAS
    # ========================================================

    $verificaciones = @()

    $usuario = $null


    try {

        # ====================================================
        # ENCABEZADO
        # ====================================================

        Write-Host ""
        Write-Host "==============================================="
        Write-Host "[INFO] INICIANDO VERIFICACION DEL EQUIPO"
        Write-Host "==============================================="


        # ====================================================
        # 1. PRIVILEGIOS ADMINISTRATIVOS
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando privilegios administrativos..."

        $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = New-Object Security.Principal.WindowsPrincipal(
            $identidad
        )

        $esAdministrador = $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )


        if ($esAdministrador) {

            Write-Host "[OK] La consola tiene privilegios administrativos."

            $verificaciones += [PSCustomObject]@{
                Modulo  = "Sistema"
                Prueba  = "Privilegios administrativos"
                Estado  = "SUCCESS"
                Detalle = "La consola tiene privilegios administrativos."
                Codigo  = 0
            }

        }
        else {

            Write-Host "[ERROR] La consola no tiene privilegios administrativos."

            $verificaciones += [PSCustomObject]@{
                Modulo  = "Sistema"
                Prueba  = "Privilegios administrativos"
                Estado  = "ERROR"
                Detalle = "La consola no tiene privilegios administrativos."
                Codigo  = 1
            }
        }


        # ====================================================
        # 2. VERIFICAR USUARIO
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando usuario '$NombreUsuario'..."

        $usuario = Get-LocalUser `
            -Name $NombreUsuario `
            -ErrorAction SilentlyContinue


        if ($null -eq $usuario) {

            Write-Host "[ERROR] El usuario '$NombreUsuario' no existe."

            $verificaciones += [PSCustomObject]@{
                Modulo  = "Usuario"
                Prueba  = "Existencia"
                Estado  = "ERROR"
                Detalle = "El usuario '$NombreUsuario' no existe."
                Codigo  = 10
            }

        }
        else {

            Write-Host "[OK] El usuario existe."

            $verificaciones += [PSCustomObject]@{
                Modulo  = "Usuario"
                Prueba  = "Existencia"
                Estado  = "SUCCESS"
                Detalle = "El usuario '$NombreUsuario' existe."
                Codigo  = 0
            }


            # =================================================
            # 2.1 CUENTA HABILITADA
            # =================================================

            Write-Host "[INFO] Verificando estado de la cuenta..."

            if ($usuario.Enabled) {

                Write-Host "[OK] El usuario esta habilitado."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "Usuario"
                    Prueba  = "Cuenta habilitada"
                    Estado  = "SUCCESS"
                    Detalle = "La cuenta esta habilitada."
                    Codigo  = 0
                }

            }
            else {

                Write-Host "[ERROR] El usuario esta deshabilitado."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "Usuario"
                    Prueba  = "Cuenta habilitada"
                    Estado  = "ERROR"
                    Detalle = "La cuenta esta deshabilitada."
                    Codigo  = 11
                }
            }


            # =================================================
            # 2.2 GRUPO USUARIOS
            # =================================================

            if ($UsuarioEstandar) {

                Write-Host ""
                Write-Host "[INFO] Verificando pertenencia al grupo de usuarios..."

                $grupoUsuarios = Get-VerificationLocalGroupBySid `
                    -Sid "S-1-5-32-545"


                if ($null -eq $grupoUsuarios) {

                    Write-Host "[ERROR] No fue posible localizar el grupo de usuarios."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Permisos"
                        Prueba  = "Grupo Usuarios"
                        Estado  = "ERROR"
                        Detalle = "No fue posible localizar el grupo mediante SID."
                        Codigo  = 20
                    }

                }
                else {

                    Write-Host "[INFO] Grupo detectado: $($grupoUsuarios.Name)"

                    $miembroUsuarios = Get-LocalGroupMember `
                        -Group $grupoUsuarios.Name `
                        -ErrorAction SilentlyContinue |
                        Where-Object {

                            $_.Name -match "\\$([regex]::Escape($NombreUsuario))$"
                        }


                    if ($null -ne $miembroUsuarios) {

                        Write-Host "[OK] El usuario pertenece al grupo de usuarios."

                        $verificaciones += [PSCustomObject]@{
                            Modulo  = "Permisos"
                            Prueba  = "Grupo Usuarios"
                            Estado  = "SUCCESS"
                            Detalle = "El usuario pertenece al grupo '$($grupoUsuarios.Name)'."
                            Codigo  = 0
                        }

                    }
                    else {

                        Write-Host "[ERROR] El usuario no pertenece al grupo de usuarios."

                        $verificaciones += [PSCustomObject]@{
                            Modulo  = "Permisos"
                            Prueba  = "Grupo Usuarios"
                            Estado  = "ERROR"
                            Detalle = "El usuario no pertenece al grupo '$($grupoUsuarios.Name)'."
                            Codigo  = 21
                        }
                    }
                }
            }


            # =================================================
            # 2.3 GRUPO ADMINISTRADORES
            # =================================================

            if ($Administrador) {

                Write-Host ""
                Write-Host "[INFO] Verificando pertenencia al grupo de administradores..."

                $grupoAdministradores = Get-VerificationLocalGroupBySid `
                    -Sid "S-1-5-32-544"


                if ($null -eq $grupoAdministradores) {

                    Write-Host "[ERROR] No fue posible localizar el grupo de administradores."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Permisos"
                        Prueba  = "Grupo Administradores"
                        Estado  = "ERROR"
                        Detalle = "No fue posible localizar el grupo mediante SID."
                        Codigo  = 30
                    }

                }
                else {

                    Write-Host "[INFO] Grupo detectado: $($grupoAdministradores.Name)"

                    $miembroAdministradores = Get-LocalGroupMember `
                        -Group $grupoAdministradores.Name `
                        -ErrorAction SilentlyContinue |
                        Where-Object {

                            $_.Name -match "\\$([regex]::Escape($NombreUsuario))$"
                        }


                    if ($null -ne $miembroAdministradores) {

                        Write-Host "[OK] El usuario pertenece al grupo de administradores."

                        $verificaciones += [PSCustomObject]@{
                            Modulo  = "Permisos"
                            Prueba  = "Grupo Administradores"
                            Estado  = "SUCCESS"
                            Detalle = "El usuario pertenece al grupo '$($grupoAdministradores.Name)'."
                            Codigo  = 0
                        }

                    }
                    else {

                        Write-Host "[ERROR] El usuario no pertenece al grupo de administradores."

                        $verificaciones += [PSCustomObject]@{
                            Modulo  = "Permisos"
                            Prueba  = "Grupo Administradores"
                            Estado  = "ERROR"
                            Detalle = "El usuario no pertenece al grupo '$($grupoAdministradores.Name)'."
                            Codigo  = 31
                        }
                    }
                }
            }
        }


        # ====================================================
        # 3. VERIFICAR CONTRASEÑA
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando configuracion de contraseña..."


        if ($null -ne $usuario) {

            try {

                # ------------------------------------------------
                # Consultar estado de expiracion mediante CIM
                # ------------------------------------------------

                $cuentaCim = Get-CimInstance `
                    -ClassName Win32_UserAccount `
                    -Filter "Name='$NombreUsuario' AND LocalAccount=True" `
                    -ErrorAction Stop


                if ($null -eq $cuentaCim) {

                    throw "No fue posible encontrar la cuenta local mediante CIM."
                }


                # ------------------------------------------------
                # Obtener PasswordExpires inmediatamente
                # ------------------------------------------------

                $passwordExpires = [bool]$cuentaCim.PasswordExpires

                $cuentaCim = $null


                # ------------------------------------------------
                # Convertir a estado PasswordNeverExpires
                # ------------------------------------------------

                $estadoPasswordNuncaExpira = -not $passwordExpires


                # ------------------------------------------------
                # Comparar estado actual contra estado esperado
                # ------------------------------------------------

                if ($estadoPasswordNuncaExpira -eq $ContrasenaNuncaExpira) {

                    if ($ContrasenaNuncaExpira) {

                        Write-Host "[OK] La contraseña esta configurada para no expirar."

                    }
                    else {

                        Write-Host "[OK] La contraseña tiene expiracion normal."
                    }


                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Contrasena"
                        Prueba  = "PasswordNeverExpires"
                        Estado  = "SUCCESS"
                        Detalle = "La configuracion de expiracion coincide con lo esperado."
                        Codigo  = 0
                    }

                }
                else {

                    Write-Host "[ERROR] La configuracion de expiracion no coincide con lo esperado."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Contrasena"
                        Prueba  = "PasswordNeverExpires"
                        Estado  = "ERROR"
                        Detalle = "Se esperaba ContrasenaNuncaExpira=$ContrasenaNuncaExpira, pero el estado actual no coincide."
                        Codigo  = 41
                    }
                }


                # ------------------------------------------------
                # Verificar UserMayChangePassword
                # ------------------------------------------------

                Write-Host "[INFO] Verificando permiso de cambio de contraseña..."


                $usuarioVerificacion = Get-LocalUser `
                    -Name $NombreUsuario `
                    -ErrorAction Stop


                $estadoCambioContrasena = [bool]$usuarioVerificacion.UserMayChangePassword


                # ------------------------------------------------
                # Comparar estado actual contra esperado
                # ------------------------------------------------

                if ($estadoCambioContrasena -eq $UsuarioPuedeCambiarContrasena) {

                    if ($UsuarioPuedeCambiarContrasena) {

                        Write-Host "[OK] El usuario puede cambiar la contraseña."

                    }
                    else {

                        Write-Host "[OK] El usuario no puede cambiar la contraseña."
                    }


                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Contrasena"
                        Prueba  = "UserMayChangePassword"
                        Estado  = "SUCCESS"
                        Detalle = "La configuracion de cambio de contraseña coincide con lo esperado."
                        Codigo  = 0
                    }

                }
                else {

                    Write-Host "[ERROR] La configuracion de cambio de contraseña no coincide con lo esperado."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Contrasena"
                        Prueba  = "UserMayChangePassword"
                        Estado  = "ERROR"
                        Detalle = "Se esperaba UsuarioPuedeCambiarContrasena=$UsuarioPuedeCambiarContrasena, pero el estado actual es $estadoCambioContrasena."
                        Codigo  = 42
                    }
                }

            }
            catch {

                Write-Host "[ERROR] No fue posible verificar completamente la contraseña."
                Write-Host "[ERROR] $($_.Exception.Message)"

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "Contrasena"
                    Prueba  = "Verificacion"
                    Estado  = "ERROR"
                    Detalle = $_.Exception.Message
                    Codigo  = 43
                }
            }
        }


        # ====================================================
        # 4. VERIFICAR SERVICIO WINRM
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando servicio WinRM..."


        try {

            $servicioWinRM = Get-Service `
                -Name "WinRM" `
                -ErrorAction Stop


            # ------------------------------------------------
            # Estado Running
            # ------------------------------------------------

            if ($servicioWinRM.Status -eq "Running") {

                Write-Host "[OK] Servicio WinRM en ejecucion."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Servicio"
                    Estado  = "SUCCESS"
                    Detalle = "WinRM esta en ejecucion."
                    Codigo  = 0
                }

            }
            else {

                Write-Host "[ERROR] WinRM no esta en ejecucion."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Servicio"
                    Estado  = "ERROR"
                    Detalle = "WinRM no esta en ejecucion. Estado actual: $($servicioWinRM.Status)."
                    Codigo  = 50
                }
            }


            # ------------------------------------------------
            # Inicio automatico
            # ------------------------------------------------

            if ($servicioWinRM.StartType -eq "Automatic") {

                Write-Host "[OK] WinRM tiene inicio automatico."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Inicio automatico"
                    Estado  = "SUCCESS"
                    Detalle = "WinRM tiene inicio automatico."
                    Codigo  = 0
                }

            }
            else {

                Write-Host "[ERROR] WinRM no tiene inicio automatico."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Inicio automatico"
                    Estado  = "ERROR"
                    Detalle = "WinRM no tiene inicio automatico. Tipo actual: $($servicioWinRM.StartType)."
                    Codigo  = 51
                }
            }

        }
        catch {

            Write-Host "[ERROR] No fue posible consultar el servicio WinRM."
            Write-Host "[ERROR] $($_.Exception.Message)"

            $verificaciones += [PSCustomObject]@{
                Modulo  = "WinRM"
                Prueba  = "Servicio"
                Estado  = "ERROR"
                Detalle = $_.Exception.Message
                Codigo  = 49
            }
        }


        # ====================================================
        # 5. VERIFICAR LISTENER WINRM
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando listener de WinRM..."


        try {

            $listenerWinRM = winrm enumerate winrm/config/listener 2>$null


            if (
                $listenerWinRM -match "Transport\s*=\s*HTTP" -and
                $listenerWinRM -match "Port\s*=\s*5985" -and
                $listenerWinRM -match "Enabled\s*=\s*true"
            ) {

                Write-Host "[OK] Listener WinRM HTTP 5985 detectado."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Listener"
                    Estado  = "SUCCESS"
                    Detalle = "Listener HTTP activo en TCP 5985."
                    Codigo  = 0
                }

            }
            else {

                Write-Host "[ERROR] No se encontro un listener WinRM HTTP 5985 activo."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Listener"
                    Estado  = "ERROR"
                    Detalle = "No se encontro listener HTTP activo en TCP 5985."
                    Codigo  = 52
                }
            }

        }
        catch {

            Write-Host "[ERROR] No fue posible verificar el listener WinRM."
            Write-Host "[ERROR] $($_.Exception.Message)"

            $verificaciones += [PSCustomObject]@{
                Modulo  = "WinRM"
                Prueba  = "Listener"
                Estado  = "ERROR"
                Detalle = $_.Exception.Message
                Codigo  = 55
            }
        }


        # ====================================================
        # 6. VERIFICAR ENDPOINT MICROSOFT.POWERSHELL
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando endpoint Microsoft.PowerShell..."


        try {

            $rutaPlugin = `
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Plugin\Microsoft.PowerShell"


            $pluginPowerShell = Get-ItemProperty `
                -Path $rutaPlugin `
                -ErrorAction Stop


            if ($null -eq $pluginPowerShell) {

                throw "No fue posible obtener la configuracion del plugin Microsoft.PowerShell."
            }


            # ------------------------------------------------
            # Obtener ConfigXML
            # ------------------------------------------------

            $configXML = $pluginPowerShell.ConfigXML


            if ([string]::IsNullOrWhiteSpace($configXML)) {

                throw "El plugin Microsoft.PowerShell existe, pero no contiene ConfigXML."
            }


            # ------------------------------------------------
            # Verificar Enabled
            # ------------------------------------------------

            if ($configXML -match 'Enabled="true"') {

                Write-Host "[OK] Plugin Microsoft.PowerShell encontrado."
                Write-Host "[OK] Endpoint Microsoft.PowerShell habilitado."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Endpoint"
                    Estado  = "SUCCESS"
                    Detalle = "Endpoint Microsoft.PowerShell registrado y habilitado."
                    Codigo  = 0
                }

            }
            else {

                Write-Host "[ERROR] El endpoint Microsoft.PowerShell esta deshabilitado."

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "WinRM"
                    Prueba  = "Endpoint"
                    Estado  = "ERROR"
                    Detalle = "El endpoint Microsoft.PowerShell esta registrado pero deshabilitado."
                    Codigo  = 53
                }
            }

        }
        catch {

            Write-Host "[ERROR] No fue posible verificar el endpoint Microsoft.PowerShell."
            Write-Host "[ERROR] $($_.Exception.Message)"

            $verificaciones += [PSCustomObject]@{
                Modulo  = "WinRM"
                Prueba  = "Endpoint"
                Estado  = "ERROR"
                Detalle = $_.Exception.Message
                Codigo  = 54
            }
        }


        # ====================================================
        # 7. VERIFICAR PERFIL DE RED
        # ====================================================

        Write-Host ""
        Write-Host "[INFO] Verificando perfil de red..."


        try {

            $perfilRed = Get-NetConnectionProfile |
                Where-Object {
                    $_.IPv4Connectivity -ne "Disconnected"
                } |
                Select-Object -First 1


            if ($null -eq $perfilRed) {

                throw "No fue posible detectar el perfil de red activo."
            }


            $categoriaRed = $perfilRed.NetworkCategory


            Write-Host "[OK] Perfil de red detectado: $categoriaRed"

            Write-Host "[INFO] Interfaz: $($perfilRed.InterfaceAlias)"
            Write-Host "[INFO] Red: $($perfilRed.Name)"


            $verificaciones += [PSCustomObject]@{
                Modulo  = "Firewall"
                Prueba  = "Perfil de red"
                Estado  = "SUCCESS"
                Detalle = "Perfil de red activo: $categoriaRed."
                Codigo  = 0
            }


        }
        catch {

            Write-Host "[ERROR] No fue posible detectar el perfil de red."
            Write-Host "[ERROR] $($_.Exception.Message)"

            $categoriaRed = $null

            $verificaciones += [PSCustomObject]@{
                Modulo  = "Firewall"
                Prueba  = "Perfil de red"
                Estado  = "ERROR"
                Detalle = $_.Exception.Message
                Codigo  = 60
            }
        }


        # ====================================================
        # 8. VERIFICAR FIREWALL
        # ====================================================

        if ($null -ne $categoriaRed) {

            try {

                Write-Host ""
                Write-Host "[INFO] Verificando Firewall..."


                $perfilFirewall = Get-NetFirewallProfile `
                    -Name $categoriaRed `
                    -ErrorAction Stop


                if ($perfilFirewall.Enabled) {

                    Write-Host "[OK] Firewall habilitado para el perfil '$categoriaRed'."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Firewall"
                        Prueba  = "Firewall habilitado"
                        Estado  = "SUCCESS"
                        Detalle = "Firewall habilitado para el perfil '$categoriaRed'."
                        Codigo  = 0
                    }

                }
                else {

                    Write-Host "[ERROR] Firewall deshabilitado para el perfil '$categoriaRed'."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Firewall"
                        Prueba  = "Firewall habilitado"
                        Estado  = "ERROR"
                        Detalle = "Firewall deshabilitado para el perfil '$categoriaRed'."
                        Codigo  = 61
                    }
                }

            }
            catch {

                Write-Host "[ERROR] No fue posible consultar el estado del Firewall."
                Write-Host "[ERROR] $($_.Exception.Message)"

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "Firewall"
                    Prueba  = "Firewall habilitado"
                    Estado  = "ERROR"
                    Detalle = $_.Exception.Message
                    Codigo  = 63
                }
            }


            # =================================================
            # 9. VERIFICAR REGLA WINRM
            # =================================================

            try {

                Write-Host "[INFO] Verificando regla WinRM..."


                $nombresReglasWinRM = @(
                    "WINRM-HTTP-In-TCP",
                    "WINRM-HTTP-In-TCP-NoScope"
                )


                $reglaEncontrada = $null


                foreach ($nombreRegla in $nombresReglasWinRM) {

                    $regla = Get-NetFirewallRule `
                        -Name $nombreRegla `
                        -ErrorAction SilentlyContinue


                    if ($null -eq $regla) {

                        continue
                    }


                    # -----------------------------------------
                    # Verificar estado de la regla
                    # -----------------------------------------

                    if (-not $regla.Enabled) {

                        continue
                    }


                    if ($regla.Direction -ne "Inbound") {

                        continue
                    }


                    if ($regla.Action -ne "Allow") {

                        continue
                    }


                    # -----------------------------------------
                    # Verificar perfil
                    # -----------------------------------------

                    $perfilRegla = $regla.Profile.ToString()


                    $perfilCoincide = (
                        $perfilRegla -eq "Any" -or
                        $perfilRegla -like "*$categoriaRed*"
                    )


                    if (-not $perfilCoincide) {

                        continue
                    }


                    # -----------------------------------------
                    # Verificar puerto
                    # -----------------------------------------

                    $filtroPuerto = $regla |
                        Get-NetFirewallPortFilter `
                            -ErrorAction SilentlyContinue


                    if ($null -eq $filtroPuerto) {

                        continue
                    }


                    $protocoloCorrecto = (
                        $filtroPuerto.Protocol -eq "TCP"
                    )


                    $puertoCorrecto = (
                        $filtroPuerto.LocalPort -eq "5985" -or
                        $filtroPuerto.LocalPort -eq 5985
                    )


                    if (
                        $protocoloCorrecto -and
                        $puertoCorrecto
                    ) {

                        $reglaEncontrada = $regla

                        break
                    }
                }


                # -----------------------------------------
                # Resultado regla
                # -----------------------------------------

                if ($null -ne $reglaEncontrada) {

                    Write-Host "[OK] Regla WinRM TCP 5985 correctamente configurada."
                    Write-Host "[OK] Regla: $($reglaEncontrada.Name)"

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Firewall"
                        Prueba  = "Regla WinRM"
                        Estado  = "SUCCESS"
                        Detalle = "Regla $($reglaEncontrada.Name) habilitada para '$categoriaRed', TCP 5985."
                        Codigo  = 0
                    }

                }
                else {

                    Write-Host "[ERROR] Regla WinRM no configurada correctamente."

                    $verificaciones += [PSCustomObject]@{
                        Modulo  = "Firewall"
                        Prueba  = "Regla WinRM"
                        Estado  = "ERROR"
                        Detalle = "No se encontro una regla WinRM TCP 5985 valida para '$categoriaRed'."
                        Codigo  = 62
                    }
                }

            }
            catch {

                Write-Host "[ERROR] No fue posible verificar la regla WinRM."
                Write-Host "[ERROR] $($_.Exception.Message)"

                $verificaciones += [PSCustomObject]@{
                    Modulo  = "Firewall"
                    Prueba  = "Regla WinRM"
                    Estado  = "ERROR"
                    Detalle = $_.Exception.Message
                    Codigo  = 64
                }
            }
        }


        # ====================================================
        # 10. RESUMEN
        # ====================================================

        Write-Host ""
        Write-Host "==============================================="
        Write-Host "[INFO] RESUMEN DE VERIFICACION"
        Write-Host "==============================================="


        $cantidadSuccess = @(
            $verificaciones |
            Where-Object {
                $_.Estado -eq "SUCCESS"
            }
        ).Count


        $cantidadWarning = @(
            $verificaciones |
            Where-Object {
                $_.Estado -eq "WARNING"
            }
        ).Count


        $cantidadError = @(
            $verificaciones |
            Where-Object {
                $_.Estado -eq "ERROR"
            }
        ).Count


        Write-Host "[OK] Verificaciones correctas : $cantidadSuccess"
        Write-Host "[WARNING] Advertencias         : $cantidadWarning"
        Write-Host "[ERROR] Errores                : $cantidadError"


        # ====================================================
        # 11. RESULTADO GLOBAL
        # ====================================================

        if ($cantidadError -gt 0) {

            $estadoGlobal = "ERROR"

            $codigoGlobal = 100

            $mensajeGlobal = `
                "La verificacion encontro $cantidadError error(es)."
        }
        elseif ($cantidadWarning -gt 0) {

            $estadoGlobal = "WARNING"

            $codigoGlobal = 101

            $mensajeGlobal = `
                "La verificacion termino con $cantidadWarning advertencia(s)."
        }
        else {

            $estadoGlobal = "SUCCESS"

            $codigoGlobal = 0

            $mensajeGlobal = `
                "Todas las verificaciones finalizaron correctamente."
        }


        # ====================================================
        # 12. RESULTADO EN CONSOLA
        # ====================================================

        Write-Host ""
        Write-Host "[RESULTADO] $estadoGlobal"
        Write-Host "[RESULTADO] $mensajeGlobal"


        # ====================================================
        # 13. RESULTADO ESTRUCTURADO
        # ====================================================

        return [PSCustomObject]@{

            Estado = $estadoGlobal

            Usuario = $NombreUsuario

            Mensaje = $mensajeGlobal

            Codigo = $codigoGlobal

            Verificaciones = $verificaciones
        }

    }
    catch {

        # ====================================================
        # ERROR GENERAL
        # ====================================================

        Write-Host ""
        Write-Host "[ERROR] Fallo inesperado durante la verificacion."
        Write-Host "[ERROR] $($_.Exception.Message)"


        return [PSCustomObject]@{

            Estado = "ERROR"

            Usuario = $NombreUsuario

            Mensaje = $_.Exception.Message

            Codigo = 99

            Verificaciones = $verificaciones
        }
    }
}