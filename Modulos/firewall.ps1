# ============================================================
# MODULO: FIREWALL
# VERSION: 1.2
# DESCRIPCION:
# Verifica la configuracion del Firewall utilizada por WinRM.
# ============================================================

function Enable-LocalFirewallWinRM {

    try {

        Write-Host "[INFO] Iniciando verificacion de Firewall para WinRM..."

        # ----------------------------------------------------
        # 1. Verificar privilegios administrativos
        # ----------------------------------------------------

        $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = New-Object Security.Principal.WindowsPrincipal($identidad)

        $esAdministrador = $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        if (-not $esAdministrador) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "La configuracion del Firewall requiere privilegios administrativos."
                Codigo  = 1
            }
        }

        Write-Host "[OK] La consola tiene privilegios administrativos."

        # ----------------------------------------------------
        # 2. Detectar perfil de red activo
        # ----------------------------------------------------

        Write-Host "[INFO] Detectando perfil de red activo..."

        $perfilRed = Get-NetConnectionProfile |
            Where-Object {
                $_.IPv4Connectivity -ne "Disconnected"
            } |
            Select-Object -First 1

        if ($null -eq $perfilRed) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "No fue posible detectar un perfil de red activo."
                Codigo  = 2
            }
        }

        $categoriaRed = $perfilRed.NetworkCategory

        Write-Host "[OK] Perfil de red detectado: $categoriaRed"
        Write-Host "[INFO] Interfaz: $($perfilRed.InterfaceAlias)"
        Write-Host "[INFO] Red: $($perfilRed.Name)"

        # ----------------------------------------------------
        # 3. Verificar Firewall del perfil activo
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando estado del Firewall..."

        $perfilFirewall = Get-NetFirewallProfile `
            -Name $categoriaRed `
            -ErrorAction Stop

        if (-not $perfilFirewall.Enabled) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "El Firewall del perfil '$categoriaRed' esta deshabilitado."
                Codigo  = 3
            }
        }

        Write-Host "[OK] Firewall habilitado para el perfil '$categoriaRed'."

        # ----------------------------------------------------
        # 4. Buscar reglas internas de WinRM
        # ----------------------------------------------------

        Write-Host "[INFO] Buscando reglas internas de WinRM..."

        $nombresReglasWinRM = @(
            "WINRM-HTTP-In-TCP",
            "WINRM-HTTP-In-TCP-NoScope"
        )

        $reglasWinRM = foreach ($nombreRegla in $nombresReglasWinRM) {

            Get-NetFirewallRule `
                -Name $nombreRegla `
                -ErrorAction SilentlyContinue
        }

        if ($null -eq $reglasWinRM) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "No se encontraron las reglas internas de Firewall de WinRM."
                Codigo  = 4
            }
        }

        Write-Host "[OK] Se encontraron reglas internas de WinRM."

        # ----------------------------------------------------
        # 5. Buscar regla habilitada para el perfil activo
        # ----------------------------------------------------

        $reglaActiva = $null

        foreach ($regla in $reglasWinRM) {

            $perfil = $regla.Profile.ToString()

            $perfilCoincide = (
                $perfil -eq "Any" -or
                $perfil -like "*$categoriaRed*"
            )

            if (
                $regla.Enabled -and
                $regla.Direction -eq "Inbound" -and
                $regla.Action -eq "Allow" -and
                $perfilCoincide
            ) {

                $reglaActiva = $regla

                break
            }
        }

        if ($null -eq $reglaActiva) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "Existe una regla WinRM, pero ninguna esta habilitada para el perfil '$categoriaRed'."
                Codigo  = 5
            }
        }

        Write-Host "[OK] Regla WinRM habilitada para el perfil '$categoriaRed'."
        Write-Host "[INFO] Regla: $($reglaActiva.Name)"
        Write-Host "[INFO] DisplayName: $($reglaActiva.DisplayName)"

        # ----------------------------------------------------
        # 6. Verificar puerto y protocolo
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando puerto y protocolo..."

        $filtroPuerto = $reglaActiva |
            Get-NetFirewallPortFilter `
            -ErrorAction Stop

        if ($null -eq $filtroPuerto) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "No fue posible obtener el filtro de puerto de la regla WinRM."
                Codigo  = 6
            }
        }

        if ($filtroPuerto.Protocol -ne "TCP") {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "La regla WinRM no utiliza el protocolo TCP."
                Codigo  = 7
            }
        }

        if (
            $filtroPuerto.LocalPort -ne "5985" -and
            $filtroPuerto.LocalPort -ne 5985
        ) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "La regla WinRM no utiliza el puerto TCP 5985."
                Codigo  = 8
            }
        }

        Write-Host "[OK] Protocolo TCP verificado."
        Write-Host "[OK] Puerto 5985 verificado."

        # ----------------------------------------------------
        # 7. Verificar direcciones
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando direcciones de la regla..."

        $filtroDireccion = $reglaActiva |
            Get-NetFirewallAddressFilter `
            -ErrorAction Stop

        if ($null -eq $filtroDireccion) {

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $env:USERNAME
                Mensaje = "La regla WinRM esta activa, pero no fue posible obtener su filtro de direcciones."
                Codigo  = 9
            }
        }

        $remoteAddress = $filtroDireccion.RemoteAddress

        if ($null -eq $remoteAddress) {

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $env:USERNAME
                Mensaje = "La regla WinRM esta activa, pero no fue posible determinar RemoteAddress."
                Codigo  = 10
            }
        }

        Write-Host "[OK] RemoteAddress detectado: $($remoteAddress -join ', ')"

        # ----------------------------------------------------
        # 8. Resultado final
        # ----------------------------------------------------

        Write-Host "[OK] Configuracion de Firewall para WinRM verificada correctamente."

        return [PSCustomObject]@{
            Estado  = "SUCCESS"
            Usuario = $env:USERNAME
            Mensaje = "Firewall habilitado y regla WinRM TCP 5985 permitida para el perfil '$categoriaRed'."
            Codigo  = 0
        }
    }

    catch {

        Write-Host "[ERROR] No fue posible verificar el Firewall."
        Write-Host "[ERROR] $($_.Exception.Message)"

        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = $env:USERNAME
            Mensaje = $_.Exception.Message
            Codigo  = 99
        }
    }
}