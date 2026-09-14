# ============================================================
# MODULO: WINRM
# VERSION: 1.1
# DESCRIPCION:
# Configura y verifica WinRM para administracion remota.
# ============================================================

function Enable-LocalWinRM {

    try {

        Write-Host "[INFO] Iniciando configuracion de WinRM..."

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
                Mensaje = "La configuracion de WinRM requiere privilegios administrativos."
                Codigo  = 1
            }
        }

        Write-Host "[OK] La consola tiene privilegios administrativos."

        # ----------------------------------------------------
        # 2. Verificar servicio WinRM
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando servicio WinRM..."

        $servicio = Get-Service `
            -Name "WinRM" `
            -ErrorAction SilentlyContinue

        if ($null -eq $servicio) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "El servicio WinRM no existe en este equipo."
                Codigo  = 2
            }
        }

        Write-Host "[OK] Servicio WinRM encontrado."
        Write-Host "[INFO] Estado actual: $($servicio.Status)"
        Write-Host "[INFO] Tipo de inicio actual: $($servicio.StartType)"

        # ----------------------------------------------------
        # 3. Configurar inicio automatico
        # ----------------------------------------------------

        if ($servicio.StartType -ne "Automatic") {

            Write-Host "[INFO] Configurando WinRM para inicio automatico..."

            Set-Service `
                -Name "WinRM" `
                -StartupType Automatic `
                -ErrorAction Stop

            Write-Host "[OK] WinRM configurado para inicio automatico."
        }
        else {

            Write-Host "[OK] WinRM ya tiene inicio automatico."
        }

        # ----------------------------------------------------
        # 4. Iniciar servicio si es necesario
        # ----------------------------------------------------

        $servicio = Get-Service `
            -Name "WinRM" `
            -ErrorAction Stop

        if ($servicio.Status -ne "Running") {

            Write-Host "[INFO] Iniciando servicio WinRM..."

            Start-Service `
                -Name "WinRM" `
                -ErrorAction Stop

            Write-Host "[OK] Servicio WinRM iniciado."
        }
        else {

            Write-Host "[OK] Servicio WinRM ya estaba iniciado."
        }

        # ----------------------------------------------------
        # 5. Verificar listener
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando listener de WinRM..."

        $listener = winrm enumerate winrm/config/listener 2>&1

        if ($LASTEXITCODE -ne 0 -or $null -eq $listener) {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "WinRM esta iniciado, pero no existe un listener funcional."
                Codigo  = 3
            }
        }

        Write-Host "[OK] Listener de WinRM detectado."

        # ----------------------------------------------------
        # 6. Verificar PowerShell Windows 5.1
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando Windows PowerShell 5.1..."

        $powershellWindows = Get-Command `
            "powershell.exe" `
            -ErrorAction SilentlyContinue

        if ($null -eq $powershellWindows) {

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $env:USERNAME
                Mensaje = "WinRM funciona, pero no se encontro powershell.exe para configurar Windows PowerShell 5.1."
                Codigo  = 4
            }
        }

        Write-Host "[OK] Windows PowerShell 5.1 disponible."

        # ----------------------------------------------------
        # 7. Configurar Windows PowerShell 5.1
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando configuracion de Windows PowerShell Remoting..."

        $resultadoPS51 = & $powershellWindows.Source `
            -NoProfile `
            -NonInteractive `
            -Command "Enable-PSRemoting -Force" 2>&1

        $codigoPS51 = $LASTEXITCODE

        if ($codigoPS51 -ne 0) {

            Write-Host "[WARNING] Windows PowerShell no pudo completar Enable-PSRemoting."

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $env:USERNAME
                Mensaje = "WinRM esta funcionando, pero Windows PowerShell Remoting no pudo configurarse completamente. Detalle: $($resultadoPS51 -join ' ')"
                Codigo  = 5
            }
        }

        Write-Host "[OK] Windows PowerShell Remoting configurado."

        # ----------------------------------------------------
        # 8. Verificar configuraciones de sesion
        # ----------------------------------------------------

        Write-Host "[INFO] Verificando endpoints de PowerShell..."

        $configuraciones = & $powershellWindows.Source `
            -NoProfile `
            -NonInteractive `
            -Command "Get-PSSessionConfiguration | Select-Object -ExpandProperty Name" 2>&1

        $codigoConfiguraciones = $LASTEXITCODE

        if ($codigoConfiguraciones -ne 0) {

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $env:USERNAME
                Mensaje = "WinRM esta funcionando, pero no fue posible verificar los endpoints de Windows PowerShell."
                Codigo  = 6
            }
        }

        $tieneMicrosoftPowerShell = $configuraciones -contains "Microsoft.PowerShell"

        if (-not $tieneMicrosoftPowerShell) {

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $env:USERNAME
                Mensaje = "WinRM esta funcionando, pero no se encontro el endpoint Microsoft.PowerShell."
                Codigo  = 7
            }
        }

        Write-Host "[OK] Endpoint Microsoft.PowerShell detectado."

        # ----------------------------------------------------
        # 9. Verificacion final del servicio
        # ----------------------------------------------------

        $servicioFinal = Get-Service `
            -Name "WinRM" `
            -ErrorAction Stop

        if ($servicioFinal.Status -ne "Running") {

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $env:USERNAME
                Mensaje = "WinRM fue configurado pero el servicio no se encuentra iniciado."
                Codigo  = 8
            }
        }

        # ----------------------------------------------------
        # 10. Resultado final
        # ----------------------------------------------------

        Write-Host "[OK] Configuracion de WinRM completada correctamente."

        return [PSCustomObject]@{
            Estado  = "SUCCESS"
            Usuario = $env:USERNAME
            Mensaje = "WinRM y Windows PowerShell Remoting fueron configurados correctamente."
            Codigo  = 0
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible completar la configuracion de WinRM."
        Write-Host "[ERROR] $($_.Exception.Message)"

        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = $env:USERNAME
            Mensaje = $_.Exception.Message
            Codigo  = 99
        }
    }
}