# ============================================================
# MODULO: CONTRASENA
# VERSION: 1.4
# ============================================================

function Set-LocalPasswordOptions {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NombreUsuario,

        [bool]$ContrasenaNuncaExpira = $false,

        [bool]$UsuarioPuedeCambiarContrasena = $true
    )

    try {

        Write-Host "[INFO] Iniciando configuracion de contraseña para '$NombreUsuario'..."

        # ----------------------------------------------------
        # 1. Verificar existencia del usuario
        # ----------------------------------------------------

        $usuario = Get-LocalUser `
            -Name $NombreUsuario `
            -ErrorAction SilentlyContinue

        if ($null -eq $usuario) {

            Write-Host "[ERROR] El usuario '$NombreUsuario' no existe."

            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = $NombreUsuario
                Mensaje = "El usuario '$NombreUsuario' no existe."
                Codigo  = 1
            }
        }

        Write-Host "[OK] Usuario encontrado."

        # ----------------------------------------------------
        # Variables para controlar el resultado
        # ----------------------------------------------------

        $expiracionAplicada = $false
        $cambioContrasenaAplicado = $false

        $mensajes = @()

        # ====================================================
        # 2. CONFIGURACION: CONTRASEÑA NUNCA EXPIRA
        # ====================================================

        Write-Host "[INFO] Configurando expiracion de contraseña..."

        try {

            Set-LocalUser `
                -Name $NombreUsuario `
                -PasswordNeverExpires $ContrasenaNuncaExpira `
                -ErrorAction Stop

            Write-Host "[OK] Configuracion de expiracion aplicada."

            # ------------------------------------------------
            # Verificar configuracion de expiracion
            # ------------------------------------------------

            Write-Host "[INFO] Verificando expiracion de contraseña..."

            $cuentaCim = Get-CimInstance `
                -ClassName Win32_UserAccount `
                -Filter "Name='$NombreUsuario' AND LocalAccount=True" `
                -ErrorAction Stop

            if ($null -eq $cuentaCim) {

                throw "No fue posible encontrar la cuenta local '$NombreUsuario' mediante CIM."
            }

            $passwordExpires = [bool]$cuentaCim.PasswordExpires

            $cuentaCim = $null

            $esperadoPasswordExpires = -not $ContrasenaNuncaExpira

            if ($passwordExpires -eq $esperadoPasswordExpires) {

                Write-Host "[OK] Verificacion de expiracion correcta."

                $expiracionAplicada = $true
            }
            else {

                Write-Host "[WARNING] La configuracion de expiracion no coincide con lo solicitado."

                $mensajes += "La verificacion de expiracion de contraseña no coincide con la configuracion solicitada."
            }
        }
        catch {

            Write-Host "[WARNING] No fue posible configurar la expiracion de contraseña."
            Write-Host "[WARNING] $($_.Exception.Message)"

            $mensajes += "No fue posible configurar la expiracion de contraseña: $($_.Exception.Message)"
        }

        # ====================================================
        # 3. CONFIGURACION: CAMBIO DE CONTRASEÑA
        # ====================================================

        Write-Host "[INFO] Configurando permiso para cambiar contraseña..."

        try {

            Set-LocalUser `
                -Name $NombreUsuario `
                -UserMayChangePassword $UsuarioPuedeCambiarContrasena `
                -ErrorAction Stop

            Write-Host "[OK] Configuracion de cambio de contraseña aplicada."

            # ------------------------------------------------
            # Verificar configuracion de cambio de contraseña
            # ------------------------------------------------

            Write-Host "[INFO] Verificando permiso de cambio de contraseña..."

            $usuarioVerificacion = Get-LocalUser `
                -Name $NombreUsuario `
                -ErrorAction Stop

            $valorCambio = [bool]$usuarioVerificacion.UserMayChangePassword

            if ($valorCambio -eq $UsuarioPuedeCambiarContrasena) {

                Write-Host "[OK] Verificacion de cambio de contraseña correcta."

                $cambioContrasenaAplicado = $true
            }
            else {

                Write-Host "[WARNING] La configuracion de cambio de contraseña no coincide con lo solicitado."

                $mensajes += "La verificacion de cambio de contraseña no coincide con la configuracion solicitada."
            }
        }
        catch {

            Write-Host "[WARNING] Windows no permitio modificar el permiso de cambio de contraseña."
            Write-Host "[WARNING] $($_.Exception.Message)"

            $mensajes += "No fue posible configurar el cambio de contraseña: $($_.Exception.Message)"
        }

        # ====================================================
        # 4. DETERMINAR RESULTADO FINAL
        # ====================================================

        # ----------------------------------------------------
        # Las dos configuraciones fueron aplicadas
        # ----------------------------------------------------

        if ($expiracionAplicada -and $cambioContrasenaAplicado) {

            $opciones = @()

            if ($ContrasenaNuncaExpira) {

                $opciones += "Contraseña nunca expira"
            }
            else {

                $opciones += "Contraseña con expiracion normal"
            }

            if ($UsuarioPuedeCambiarContrasena) {

                $opciones += "Usuario puede cambiar contraseña"
            }
            else {

                $opciones += "Usuario no puede cambiar contraseña"
            }

            $descripcion = $opciones -join " + "

            Write-Host "[OK] Configuracion de contraseña completada."
            Write-Host "[OK] $descripcion."

            return [PSCustomObject]@{
                Estado  = "SUCCESS"
                Usuario = $NombreUsuario
                Mensaje = "Configuracion de contraseña aplicada correctamente: $descripcion."
                Codigo  = 0
            }
        }

        # ----------------------------------------------------
        # Una de las configuraciones fue aplicada
        # ----------------------------------------------------

        if ($expiracionAplicada -or $cambioContrasenaAplicado) {

            $detalle = $mensajes -join " | "

            Write-Host "[WARNING] Configuracion de contraseña completada con advertencias."
            Write-Host "[WARNING] $detalle"

            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = $NombreUsuario
                Mensaje = "Configuracion de contraseña completada parcialmente. $detalle"
                Codigo  = 5
            }
        }

        # ----------------------------------------------------
        # Ninguna configuracion fue aplicada
        # ----------------------------------------------------

        $detalle = $mensajes -join " | "

        Write-Host "[ERROR] No fue posible aplicar la configuracion de contraseña."
        Write-Host "[ERROR] $detalle"

        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = $NombreUsuario
            Mensaje = "No fue posible aplicar la configuracion de contraseña. $detalle"
            Codigo  = 8
        }
    }
    catch {

        Write-Host "[ERROR] Error inesperado en el modulo de contraseña."
        Write-Host "[ERROR] $($_.Exception.Message)"

        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = $NombreUsuario
            Mensaje = $_.Exception.Message
            Codigo  = 9
        }
    }
}