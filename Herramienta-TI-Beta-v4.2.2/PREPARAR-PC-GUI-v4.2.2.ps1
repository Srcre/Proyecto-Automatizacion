Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# HERRAMIENTA DE SOPORTE TI
# PREPARAR COMPUTADOR - V4.2.2
#
# EJECUCIÓN EN SEGUNDO PLANO
#
# ============================================================
# CORRECCIÓN V4.2.2
#
# PROBLEMA DETECTADO:
#
# 1. Al finalizar el proceso, el MessageBox de "Proceso
#    completado" se mostraba antes de terminar completamente
#    la limpieza del Runspace.
#
# 2. Mientras el MessageBox estaba abierto, la aplicación
#    todavía podía considerar que el proceso estaba
#    "FINALIZANDO".
#
# 3. Al cerrar la ventana durante ese momento podía aparecer
#    incorrectamente:
#
#       "Hay un proceso de preparación ejecutándose."
#
# 4. La notificación final podía aparecer más de una vez
#    bajo determinadas condiciones de ejecución.
#
# SOLUCIÓN:
#
# - La limpieza del Runspace ocurre ANTES del MessageBox final.
# - El estado vuelve a INACTIVO antes de mostrar la notificación.
# - El Timer se detiene antes de procesar el resultado.
# - Se agrega protección contra notificaciones duplicadas.
# - Se mantiene protección contra doble ejecución.
# - La GUI queda completamente reutilizable después de cada
#   ejecución.
# ============================================================


# ============================================================
# VARIABLES GLOBALES
# ============================================================

$script:Runspace = $null
$script:PowerShell = $null
$script:AsyncResult = $null

$script:EstadoProceso = "INACTIVO"

$script:ProcesoExitoso = $false
$script:ProcesoCompletado = $false

$script:NotificacionMostrada = $false


# ============================================================
# VALIDAR ADMINISTRADOR
# ============================================================

function Test-Administrador {

    $identidad =
        [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal =
        New-Object Security.Principal.WindowsPrincipal(
            $identidad
        )

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


if (-not (Test-Administrador)) {

    [System.Windows.Forms.MessageBox]::Show(
        "Esta herramienta debe ejecutarse como Administrador.",
        "Permisos insuficientes",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )

    exit
}


# ============================================================
# OBTENER SIGUIENTE USUARIO
# ============================================================

function Obtener-SiguienteUsuario {

    $numero = 0

    while ($true) {

        if ($numero -eq 0) {

            $nombre = "prueba"
        }
        else {

            $nombre = "prueba$numero"
        }

        $usuarioExiste =
            Get-LocalUser `
                -Name $nombre `
                -ErrorAction SilentlyContinue

        if (-not $usuarioExiste) {

            return $nombre
        }

        $numero++
    }
}


# ============================================================
# ESCRIBIR LOG
# ============================================================

function Escribir-Log {

    param(
        [string]$Mensaje,
        [string]$Tipo = "INFO"
    )

    $hora =
        Get-Date -Format "HH:mm:ss"

    switch ($Tipo) {

        "OK" {

            $texto =
                "[$hora] [OK] $Mensaje"
        }

        "ERROR" {

            $texto =
                "[$hora] [ERROR] $Mensaje"
        }

        "WARN" {

            $texto =
                "[$hora] [ADVERTENCIA] $Mensaje"
        }

        default {

            $texto =
                "[$hora] [INFO] $Mensaje"
        }
    }

    $txtLog.AppendText(
        $texto + [Environment]::NewLine
    )

    $txtLog.SelectionStart =
        $txtLog.Text.Length

    $txtLog.ScrollToCaret()
}


# ============================================================
# ACTUALIZAR ESTADO
# ============================================================

function Actualizar-Estado {

    param(
        [string]$Texto,
        [int]$Progreso
    )

    $lblEstado.Text = $Texto

    if (
        $Progreso -ge 0 -and
        $Progreso -le 100
    ) {

        $progressBar.Value =
            $Progreso
    }
}


# ============================================================
# HABILITAR / DESHABILITAR CONTROLES
# ============================================================

function Cambiar-Controles {

    param(
        [bool]$Habilitar
    )

    $btnPreparar.Enabled =
        $Habilitar

    $btnSiguiente.Enabled =
        $Habilitar

    $txtUsuario.Enabled =
        $Habilitar

    $txtPassword.Enabled =
        $Habilitar

    $checkUsuario.Enabled =
        $Habilitar

    $checkAdministrador.Enabled =
        $Habilitar

    $checkPasswordNuncaExpira.Enabled =
        $Habilitar

    $checkNoPuedeCambiar.Enabled =
        $Habilitar

    $checkWinRM.Enabled =
        $Habilitar

    $checkServicio.Enabled =
        $Habilitar

    $checkFirewall.Enabled =
        $Habilitar
}


# ============================================================
# LIMPIAR RUNSPACE
# ============================================================

function Limpiar-Runspace {

    try {

        # ----------------------------------------------------
        # POWER SHELL
        # ----------------------------------------------------

        if ($script:PowerShell) {

            try {

                if (
                    $script:AsyncResult -and
                    -not $script:AsyncResult.IsCompleted
                ) {

                    $script:PowerShell.Stop()
                }
            }
            catch {
            }

            try {

                $script:PowerShell.Dispose()
            }
            catch {
            }
        }


        # ----------------------------------------------------
        # RUNSPACE
        # ----------------------------------------------------

        if ($script:Runspace) {

            try {

                if (
                    $script:Runspace.RunspaceStateInfo.State `
                    -ne `
                    [System.Management.Automation.Runspaces.RunspaceState]::Closed
                ) {

                    $script:Runspace.Close()
                }
            }
            catch {
            }

            try {

                $script:Runspace.Dispose()
            }
            catch {
            }
        }
    }
    finally {

        # ----------------------------------------------------
        # ELIMINAR TODAS LAS REFERENCIAS
        # ----------------------------------------------------

        $script:PowerShell = $null

        $script:Runspace = $null

        $script:AsyncResult = $null
    }
}


# ============================================================
# FORMULARIO
# ============================================================

$form =
    New-Object System.Windows.Forms.Form

$form.Text =
    "Herramienta de TI"

$form.Size =
    New-Object System.Drawing.Size(
        720,
        820
    )

$form.StartPosition =
    "CenterScreen"

$form.FormBorderStyle =
    "FixedSingle"

$form.MaximizeBox =
    $false

$form.MinimizeBox =
    $true

$form.BackColor =
    [System.Drawing.Color]::White


# ============================================================
# TÍTULO
# ============================================================

$lblTitulo =
    New-Object System.Windows.Forms.Label

$lblTitulo.Text =
    "HERRAMIENTA DE TI"

$lblTitulo.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        18,
        [System.Drawing.FontStyle]::Bold
    )

$lblTitulo.AutoSize =
    $true

$lblTitulo.Location =
    New-Object System.Drawing.Point(
        190,
        20
    )

$form.Controls.Add(
    $lblTitulo
)


# ============================================================
# SUBTÍTULO
# ============================================================

$lblSubtitulo =
    New-Object System.Windows.Forms.Label

$lblSubtitulo.Text =
    "PREPARAR COMPUTADOR"

$lblSubtitulo.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        11
    )

$lblSubtitulo.AutoSize =
    $true

$lblSubtitulo.Location =
    New-Object System.Drawing.Point(
        270,
        58
    )

$form.Controls.Add(
    $lblSubtitulo
)


# ============================================================
# DATOS DE LA CUENTA
# ============================================================

$groupUsuario =
    New-Object System.Windows.Forms.GroupBox

$groupUsuario.Text =
    "Datos de la cuenta"

$groupUsuario.Location =
    New-Object System.Drawing.Point(
        25,
        95
    )

$groupUsuario.Size =
    New-Object System.Drawing.Size(
        650,
        115
    )

$form.Controls.Add(
    $groupUsuario
)


# ============================================================
# NOMBRE DE USUARIO
# ============================================================

$lblUsuario =
    New-Object System.Windows.Forms.Label

$lblUsuario.Text =
    "Nombre de usuario:"

$lblUsuario.Location =
    New-Object System.Drawing.Point(
        20,
        30
    )

$lblUsuario.AutoSize =
    $true

$groupUsuario.Controls.Add(
    $lblUsuario
)


$txtUsuario =
    New-Object System.Windows.Forms.TextBox

$txtUsuario.Location =
    New-Object System.Drawing.Point(
        160,
        27
    )

$txtUsuario.Size =
    New-Object System.Drawing.Size(
        200,
        25
    )

$txtUsuario.Text =
    Obtener-SiguienteUsuario

$groupUsuario.Controls.Add(
    $txtUsuario
)


# ============================================================
# GENERAR SIGUIENTE
# ============================================================

$btnSiguiente =
    New-Object System.Windows.Forms.Button

$btnSiguiente.Text =
    "Generar siguiente"

$btnSiguiente.Location =
    New-Object System.Drawing.Point(
        380,
        25
    )

$btnSiguiente.Size =
    New-Object System.Drawing.Size(
        150,
        28
    )

$btnSiguiente.Add_Click({

    if (
        $script:EstadoProceso -ne "INACTIVO"
    ) {

        return
    }

    $txtUsuario.Text =
        Obtener-SiguienteUsuario

    Escribir-Log `
        "Siguiente usuario generado: $($txtUsuario.Text)"
})

$groupUsuario.Controls.Add(
    $btnSiguiente
)


# ============================================================
# CONTRASEÑA
# ============================================================

$lblPassword =
    New-Object System.Windows.Forms.Label

$lblPassword.Text =
    "Contraseña:"

$lblPassword.Location =
    New-Object System.Drawing.Point(
        20,
        70
    )

$lblPassword.AutoSize =
    $true

$groupUsuario.Controls.Add(
    $lblPassword
)


$txtPassword =
    New-Object System.Windows.Forms.TextBox

$txtPassword.Location =
    New-Object System.Drawing.Point(
        160,
        67
    )

$txtPassword.Size =
    New-Object System.Drawing.Size(
        200,
        25
    )

$txtPassword.Text =
    "prueba"

$txtPassword.PasswordChar =
    "*"

$groupUsuario.Controls.Add(
    $txtPassword
)


# ============================================================
# PERMISOS
# ============================================================

$groupPermisos =
    New-Object System.Windows.Forms.GroupBox

$groupPermisos.Text =
    "Permisos de la cuenta"

$groupPermisos.Location =
    New-Object System.Drawing.Point(
        25,
        225
    )

$groupPermisos.Size =
    New-Object System.Drawing.Size(
        315,
        125
    )

$form.Controls.Add(
    $groupPermisos
)


# Usuario estándar

$checkUsuario =
    New-Object System.Windows.Forms.CheckBox

$checkUsuario.Text =
    "Usuario estándar"

$checkUsuario.Location =
    New-Object System.Drawing.Point(
        20,
        30
    )

$checkUsuario.AutoSize =
    $true

$checkUsuario.Checked =
    $true

$groupPermisos.Controls.Add(
    $checkUsuario
)


# Administrador

$checkAdministrador =
    New-Object System.Windows.Forms.CheckBox

$checkAdministrador.Text =
    "Administrador"

$checkAdministrador.Location =
    New-Object System.Drawing.Point(
        20,
        65
    )

$checkAdministrador.AutoSize =
    $true

$checkAdministrador.Checked =
    $false

$groupPermisos.Controls.Add(
    $checkAdministrador
)


# Información

$lblInfoPermisos =
    New-Object System.Windows.Forms.Label

$lblInfoPermisos.Text =
    "Se pueden seleccionar ambos."

$lblInfoPermisos.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        8
    )

$lblInfoPermisos.ForeColor =
    [System.Drawing.Color]::Gray

$lblInfoPermisos.Location =
    New-Object System.Drawing.Point(
        20,
        92
    )

$lblInfoPermisos.AutoSize =
    $true

$groupPermisos.Controls.Add(
    $lblInfoPermisos
)


# ============================================================
# OPCIONES DE CONTRASEÑA
# ============================================================

$groupPassword =
    New-Object System.Windows.Forms.GroupBox

$groupPassword.Text =
    "Opciones de contraseña"

$groupPassword.Location =
    New-Object System.Drawing.Point(
        360,
        225
    )

$groupPassword.Size =
    New-Object System.Drawing.Size(
        315,
        125
    )

$form.Controls.Add(
    $groupPassword
)


# Nunca expira

$checkPasswordNuncaExpira =
    New-Object System.Windows.Forms.CheckBox

$checkPasswordNuncaExpira.Text =
    "Contraseña nunca expira"

$checkPasswordNuncaExpira.Location =
    New-Object System.Drawing.Point(
        20,
        30
    )

$checkPasswordNuncaExpira.AutoSize =
    $true

$checkPasswordNuncaExpira.Checked =
    $true

$groupPassword.Controls.Add(
    $checkPasswordNuncaExpira
)


# No puede cambiar

$checkNoPuedeCambiar =
    New-Object System.Windows.Forms.CheckBox

$checkNoPuedeCambiar.Text =
    "Usuario no puede cambiar la contraseña"

$checkNoPuedeCambiar.Location =
    New-Object System.Drawing.Point(
        20,
        65
    )

$checkNoPuedeCambiar.AutoSize =
    $true

$checkNoPuedeCambiar.Checked =
    $false

$groupPassword.Controls.Add(
    $checkNoPuedeCambiar
)


# ============================================================
# CONFIGURACIÓN REMOTA
# ============================================================

$groupRemoto =
    New-Object System.Windows.Forms.GroupBox

$groupRemoto.Text =
    "Configuración de administración remota"

$groupRemoto.Location =
    New-Object System.Drawing.Point(
        25,
        365
    )

$groupRemoto.Size =
    New-Object System.Drawing.Size(
        650,
        105
    )

$form.Controls.Add(
    $groupRemoto
)


# WinRM

$checkWinRM =
    New-Object System.Windows.Forms.CheckBox

$checkWinRM.Text =
    "Habilitar WinRM / PowerShell Remoting"

$checkWinRM.Location =
    New-Object System.Drawing.Point(
        20,
        30
    )

$checkWinRM.AutoSize =
    $true

$checkWinRM.Checked =
    $true

$groupRemoto.Controls.Add(
    $checkWinRM
)


# Servicio

$checkServicio =
    New-Object System.Windows.Forms.CheckBox

$checkServicio.Text =
    "Configurar servicio WinRM como automático"

$checkServicio.Location =
    New-Object System.Drawing.Point(
        20,
        60
    )

$checkServicio.AutoSize =
    $true

$checkServicio.Checked =
    $true

$groupRemoto.Controls.Add(
    $checkServicio
)


# Firewall

$checkFirewall =
    New-Object System.Windows.Forms.CheckBox

$checkFirewall.Text =
    "Configurar firewall para WinRM"

$checkFirewall.Location =
    New-Object System.Drawing.Point(
        350,
        30
    )

$checkFirewall.AutoSize =
    $true

$checkFirewall.Checked =
    $true

$groupRemoto.Controls.Add(
    $checkFirewall
)


# ============================================================
# ESTADO
# ============================================================

$lblEstado =
    New-Object System.Windows.Forms.Label

$lblEstado.Text =
    "Listo para preparar el computador"

$lblEstado.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10,
        [System.Drawing.FontStyle]::Bold
    )

$lblEstado.Location =
    New-Object System.Drawing.Point(
        25,
        490
    )

$lblEstado.AutoSize =
    $true

$form.Controls.Add(
    $lblEstado
)


# ============================================================
# BARRA DE PROGRESO
# ============================================================

$progressBar =
    New-Object System.Windows.Forms.ProgressBar

$progressBar.Location =
    New-Object System.Drawing.Point(
        25,
        520
    )

$progressBar.Size =
    New-Object System.Drawing.Size(
        650,
        25
    )

$progressBar.Minimum =
    0

$progressBar.Maximum =
    100

$progressBar.Value =
    0

$form.Controls.Add(
    $progressBar
)


# ============================================================
# LOG
# ============================================================

$lblLog =
    New-Object System.Windows.Forms.Label

$lblLog.Text =
    "Registro de actividad:"

$lblLog.Location =
    New-Object System.Drawing.Point(
        25,
        560
    )

$lblLog.AutoSize =
    $true

$form.Controls.Add(
    $lblLog
)


$txtLog =
    New-Object System.Windows.Forms.TextBox

$txtLog.Location =
    New-Object System.Drawing.Point(
        25,
        585
    )

$txtLog.Size =
    New-Object System.Drawing.Size(
        650,
        100
    )

$txtLog.Multiline =
    $true

$txtLog.ScrollBars =
    "Vertical"

$txtLog.ReadOnly =
    $true

$txtLog.BackColor =
    [System.Drawing.Color]::White

$form.Controls.Add(
    $txtLog
)


# ============================================================
# BOTÓN PREPARAR
# ============================================================

$btnPreparar =
    New-Object System.Windows.Forms.Button

$btnPreparar.Text =
    "PREPARAR PC"

$btnPreparar.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        11,
        [System.Drawing.FontStyle]::Bold
    )

$btnPreparar.Location =
    New-Object System.Drawing.Point(
        225,
        700
    )

$btnPreparar.Size =
    New-Object System.Drawing.Size(
        270,
        45
    )

$form.Controls.Add(
    $btnPreparar
)


# ============================================================
# TIMER
# ============================================================

$timer =
    New-Object System.Windows.Forms.Timer

$timer.Interval =
    300


# ============================================================
# INICIAR PREPARACIÓN
# ============================================================

$btnPreparar.Add_Click({

    # ========================================================
    # PROTECCIÓN CONTRA DOBLE EJECUCIÓN
    # ========================================================

    if (
        $script:EstadoProceso -ne "INACTIVO"
    ) {

        return
    }


    # ========================================================
    # VALIDACIONES
    # ========================================================

    if (
        [string]::IsNullOrWhiteSpace(
            $txtUsuario.Text
        )
    ) {

        [System.Windows.Forms.MessageBox]::Show(
            "Debes ingresar un nombre de usuario.",
            "Validación"
        )

        return
    }


    if (
        [string]::IsNullOrWhiteSpace(
            $txtPassword.Text
        )
    ) {

        [System.Windows.Forms.MessageBox]::Show(
            "Debes ingresar una contraseña.",
            "Validación"
        )

        return
    }


    if (
        (-not $checkUsuario.Checked) -and
        (-not $checkAdministrador.Checked)
    ) {

        [System.Windows.Forms.MessageBox]::Show(
            "Debes seleccionar al menos un tipo de permiso.",
            "Validación"
        )

        return
    }


    # ========================================================
    # INICIAR ESTADO
    # ========================================================

    $script:EstadoProceso =
        "EJECUTANDO"

    $script:ProcesoExitoso =
        $false

    $script:ProcesoCompletado =
        $false

    $script:NotificacionMostrada =
        $false


    # ========================================================
    # DESHABILITAR CONTROLES
    # ========================================================

    Cambiar-Controles $false

    $txtLog.Clear()


    Actualizar-Estado `
        "Preparando proceso..." `
        0


    Escribir-Log `
        "Iniciando preparación en segundo plano."


    # ========================================================
    # CAPTURAR CONFIGURACIÓN
    # ========================================================

    $config =
        [PSCustomObject]@{

            NombreUsuario =
                $txtUsuario.Text.Trim()

            Password =
                $txtPassword.Text

            UsuarioEstandar =
                $checkUsuario.Checked

            Administrador =
                $checkAdministrador.Checked

            PasswordNuncaExpira =
                $checkPasswordNuncaExpira.Checked

            NoPuedeCambiarPassword =
                $checkNoPuedeCambiar.Checked

            WinRM =
                $checkWinRM.Checked

            Servicio =
                $checkServicio.Checked

            Firewall =
                $checkFirewall.Checked
        }


    # ========================================================
    # CREAR RUNSPACE
    # ========================================================

    try {

        # ----------------------------------------------------
        # Asegurar que no existan referencias antiguas
        # ----------------------------------------------------

        Limpiar-Runspace


        # ----------------------------------------------------
        # Crear Runspace
        # ----------------------------------------------------

        $script:Runspace =
            [RunspaceFactory]::CreateRunspace()

        $script:Runspace.ApartmentState =
            "STA"

        $script:Runspace.ThreadOptions =
            "ReuseThread"

        $script:Runspace.Open()


        # ----------------------------------------------------
        # Crear PowerShell
        # ----------------------------------------------------

        $script:PowerShell =
            [PowerShell]::Create()

        $script:PowerShell.Runspace =
            $script:Runspace


        # ====================================================
        # MOTOR DE PREPARACIÓN
        # ====================================================

        [void]$script:PowerShell.AddScript({

            param($config)


            # =================================================
            # RESULTADO
            # =================================================

            function Resultado {

                param(
                    [int]$Progreso,
                    [string]$Mensaje,
                    [string]$Tipo = "INFO"
                )

                [PSCustomObject]@{

                    Progreso =
                        $Progreso

                    Mensaje =
                        $Mensaje

                    Tipo =
                        $Tipo
                }
            }


            try {

                # =================================================
                # DATOS
                # =================================================

                $nombreUsuario =
                    $config.NombreUsuario


                $password =
                    ConvertTo-SecureString `
                        $config.Password `
                        -AsPlainText `
                        -Force


                Resultado `
                    5 `
                    "Proceso iniciado."


                # =================================================
                # GRUPOS
                # =================================================

                Resultado `
                    10 `
                    "Detectando grupos locales..."


                $grupoUsuarios =
                    Get-LocalGroup |
                    Where-Object {

                        $_.SID.Value `
                            -eq `
                        "S-1-5-32-545"

                    } |
                    Select-Object -First 1


                $grupoAdministradores =
                    Get-LocalGroup |
                    Where-Object {

                        $_.SID.Value `
                            -eq `
                        "S-1-5-32-544"

                    } |
                    Select-Object -First 1


                if (-not $grupoUsuarios) {

                    throw `
                        "No fue posible encontrar el grupo Usuarios."
                }


                if (-not $grupoAdministradores) {

                    throw `
                        "No fue posible encontrar el grupo Administradores."
                }


                Resultado `
                    12 `
                    "Grupos detectados correctamente." `
                    "OK"


                # =================================================
                # USUARIO
                # =================================================

                Resultado `
                    15 `
                    "Verificando disponibilidad del usuario..."


                $usuarioExistente =
                    Get-LocalUser `
                        -Name $nombreUsuario `
                        -ErrorAction SilentlyContinue


                if ($usuarioExistente) {

                    throw `
                        "El usuario '$nombreUsuario' ya existe."
                }


                Resultado `
                    18 `
                    "El usuario está disponible." `
                    "OK"


                # =================================================
                # WINRM
                # =================================================

                if ($config.WinRM) {

                    Resultado `
                        25 `
                        "Configurando WinRM..."


                    Enable-PSRemoting `
                        -Force `
                        -ErrorAction Stop


                    Resultado `
                        30 `
                        "WinRM habilitado correctamente." `
                        "OK"
                }
                else {

                    Resultado `
                        30 `
                        "WinRM no seleccionado." `
                        "WARN"
                }


                # =================================================
                # SERVICIO
                # =================================================

                if ($config.Servicio) {

                    Resultado `
                        35 `
                        "Configurando servicio WinRM..."


                    Set-Service `
                        -Name WinRM `
                        -StartupType Automatic `
                        -ErrorAction Stop


                    Start-Service `
                        -Name WinRM `
                        -ErrorAction Stop


                    Resultado `
                        40 `
                        "Servicio WinRM configurado y ejecutándose." `
                        "OK"
                }
                else {

                    Resultado `
                        40 `
                        "Configuración automática del servicio no seleccionada." `
                        "WARN"
                }


                # =================================================
                # FIREWALL
                # =================================================

                if ($config.Firewall) {

                    Resultado `
                        45 `
                        "Configurando firewall para WinRM..."


                    Enable-PSRemoting `
                        -Force `
                        -ErrorAction Stop


                    Resultado `
                        50 `
                        "Reglas necesarias de WinRM configuradas." `
                        "OK"
                }
                else {

                    Resultado `
                        50 `
                        "Configuración de firewall no seleccionada." `
                        "WARN"
                }


                # =================================================
                # CREAR USUARIO
                # =================================================

                Resultado `
                    55 `
                    "Creando usuario '$nombreUsuario'..."


                New-LocalUser `
                    -Name $nombreUsuario `
                    -Password $password `
                    -Description "Cuenta de prueba" `
                    -ErrorAction Stop


                Resultado `
                    60 `
                    "Usuario '$nombreUsuario' creado correctamente." `
                    "OK"


                # =================================================
                # CONTRASEÑA
                # =================================================

                Resultado `
                    65 `
                    "Configurando opciones de contraseña..."


                Set-LocalUser `
                    -Name $nombreUsuario `
                    -PasswordNeverExpires `
                        $config.PasswordNuncaExpira `
                    -UserMayChangePassword `
                        (-not $config.NoPuedeCambiarPassword) `
                    -ErrorAction Stop


                if ($config.PasswordNuncaExpira) {

                    Resultado `
                        67 `
                        "Contraseña configurada como 'Nunca expira'." `
                        "OK"
                }
                else {

                    Resultado `
                        67 `
                        "Contraseña configurada para poder expirar." `
                        "OK"
                }


                if ($config.NoPuedeCambiarPassword) {

                    Resultado `
                        68 `
                        "Usuario no puede cambiar la contraseña." `
                        "OK"
                }
                else {

                    Resultado `
                        68 `
                        "Usuario puede cambiar la contraseña." `
                        "OK"
                }


                # =================================================
                # GRUPO USUARIOS
                # =================================================

                if ($config.UsuarioEstandar) {

                    Resultado `
                        72 `
                        "Agregando usuario al grupo Usuarios..."


                    Add-LocalGroupMember `
                        -Group $grupoUsuarios.Name `
                        -Member $nombreUsuario `
                        -ErrorAction Stop


                    Resultado `
                        75 `
                        "Usuario agregado al grupo Usuarios." `
                        "OK"
                }


                # =================================================
                # GRUPO ADMINISTRADORES
                # =================================================

                if ($config.Administrador) {

                    Resultado `
                        78 `
                        "Agregando usuario al grupo Administradores..."


                    Add-LocalGroupMember `
                        -Group $grupoAdministradores.Name `
                        -Member $nombreUsuario `
                        -ErrorAction Stop


                    Resultado `
                        80 `
                        "Usuario agregado al grupo Administradores." `
                        "OK"
                }


                # =================================================
                # VERIFICACIÓN
                # =================================================

                Resultado `
                    85 `
                    "Iniciando verificación final..."


                $usuarioVerificado =
                    Get-LocalUser `
                        -Name $nombreUsuario `
                        -ErrorAction Stop


                # =================================================
                # VERIFICAR USUARIOS
                # =================================================

                if ($config.UsuarioEstandar) {

                    $miembroUsuarios =
                        Get-LocalGroupMember `
                            -Group $grupoUsuarios.Name `
                            -ErrorAction Stop |
                        Where-Object {

                            $_.Name -match `
                            "\\$([regex]::Escape($nombreUsuario))$"

                        }


                    if (-not $miembroUsuarios) {

                        throw `
                            "El usuario no pertenece al grupo Usuarios."
                    }


                    Resultado `
                        87 `
                        "Verificación del grupo Usuarios: correcta." `
                        "OK"
                }


                # =================================================
                # VERIFICAR ADMINISTRADORES
                # =================================================

                if ($config.Administrador) {

                    $miembroAdministradores =
                        Get-LocalGroupMember `
                            -Group $grupoAdministradores.Name `
                            -ErrorAction Stop |
                        Where-Object {

                            $_.Name -match `
                            "\\$([regex]::Escape($nombreUsuario))$"

                        }


                    if (-not $miembroAdministradores) {

                        throw `
                            "El usuario no pertenece al grupo Administradores."
                    }


                    Resultado `
                        89 `
                        "Verificación del grupo Administradores: correcta." `
                        "OK"
                }


                # =================================================
                # VERIFICAR EXPIRACIÓN
                # =================================================

                Resultado `
                    91 `
                    "Verificando expiración de contraseña..."


                $cuentaCim =
                    Get-CimInstance `
                        Win32_UserAccount `
                        -Filter `
                        "Name='$nombreUsuario' AND LocalAccount=True" `
                        -ErrorAction Stop


                if (-not $cuentaCim) {

                    throw `
                        "No fue posible obtener la cuenta mediante CIM."
                }


                $debeExpirar =
                    [bool](
                        -not $config.PasswordNuncaExpira
                    )


                $valorRealExpira =
                    [bool](
                        $cuentaCim.PasswordExpires
                    )


                if (
                    $valorRealExpira `
                    -ne `
                    $debeExpirar
                ) {

                    throw `
                        "La verificación de expiración de contraseña falló. Esperado: $debeExpirar. Obtenido: $valorRealExpira."
                }


                Resultado `
                    93 `
                    "Verificación de expiración de contraseña: correcta." `
                    "OK"


                # =================================================
                # VERIFICAR CAMBIO DE PASSWORD
                # =================================================

                $debePoderCambiar =
                    [bool](
                        -not $config.NoPuedeCambiarPassword
                    )


                $valorRealPuedeCambiar =
                    [bool](
                        $usuarioVerificado.UserMayChangePassword
                    )


                if (
                    $valorRealPuedeCambiar `
                    -ne `
                    $debePoderCambiar
                ) {

                    throw `
                        "La verificación de cambio de contraseña falló. Esperado: $debePoderCambiar. Obtenido: $valorRealPuedeCambiar."
                }


                Resultado `
                    95 `
                    "Verificación de cambio de contraseña: correcta." `
                    "OK"


                # =================================================
                # VERIFICAR WINRM
                # =================================================

                if ($config.WinRM) {

                    $servicioWinRM =
                        Get-Service `
                            -Name WinRM `
                            -ErrorAction Stop


                    if (
                        $servicioWinRM.Status `
                        -ne `
                        "Running"
                    ) {

                        throw `
                            "WinRM está configurado pero el servicio no está ejecutándose."
                    }


                    Resultado `
                        97 `
                        "Verificación de WinRM: correcta." `
                        "OK"
                }


                # =================================================
                # FINAL
                # =================================================

                Resultado `
                    100 `
                    "PREPARACIÓN COMPLETADA CORRECTAMENTE." `
                    "OK"
            }
            catch {

                Resultado `
                    0 `
                    $_.Exception.Message `
                    "ERROR"
            }

        }).AddArgument($config)


        # ====================================================
        # INICIAR RUNSPACE
        # ====================================================

        $script:AsyncResult =
            $script:PowerShell.BeginInvoke()


        # ====================================================
        # INICIAR TIMER
        # ====================================================

        $timer.Start()
    }
    catch {

        $script:EstadoProceso =
            "ERROR"

        Escribir-Log `
            $_.Exception.Message `
            "ERROR"

        Limpiar-Runspace

        Cambiar-Controles $true

        $script:EstadoProceso =
            "INACTIVO"


        [System.Windows.Forms.MessageBox]::Show(
            "No fue posible iniciar el proceso:`n`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})


# ============================================================
# TIMER
# ============================================================

$timer.Add_Tick({

    # ========================================================
    # NO HAY PROCESO
    # ========================================================

    if (
        $script:EstadoProceso -eq "INACTIVO"
    ) {

        $timer.Stop()

        return
    }


    # ========================================================
    # NO EXISTE RESULTADO ASÍNCRONO
    # ========================================================

    if (
        $null -eq $script:AsyncResult
    ) {

        return
    }


    # ========================================================
    # TODAVÍA EJECUTANDO
    # ========================================================

    if (
        -not $script:AsyncResult.IsCompleted
    ) {

        return
    }


    # ========================================================
    # MARCAR COMO FINALIZANDO
    # ========================================================

    $script:EstadoProceso =
        "FINALIZANDO"


    # ========================================================
    # DETENER TIMER
    # ========================================================

    $timer.Stop()


    # ========================================================
    # VARIABLES LOCALES
    # ========================================================

    $exito = $false

    $mensajeFinal = ""


    try {

        # ====================================================
        # OBTENER RESULTADOS
        # ====================================================

        $resultados =
            $script:PowerShell.EndInvoke(
                $script:AsyncResult
            )


        # ====================================================
        # MOSTRAR RESULTADOS
        # ====================================================

        foreach ($resultado in $resultados) {

            Actualizar-Estado `
                $resultado.Mensaje `
                $resultado.Progreso

            Escribir-Log `
                $resultado.Mensaje `
                $resultado.Tipo
        }


        # ====================================================
        # OBTENER ÚLTIMO RESULTADO
        # ====================================================

        $ultimoResultado =
            $resultados |
            Select-Object -Last 1


        if (
            $ultimoResultado `
            -and
            $ultimoResultado.Tipo -eq "OK" `
            -and
            $ultimoResultado.Progreso -eq 100
        ) {

            $exito = $true

            $mensajeFinal =
                "El computador fue preparado correctamente.`n`nUsuario: $($txtUsuario.Text)"
        }
        else {

            $exito = $false

            $mensajeFinal =
                "El proceso no pudo completarse.`n`nRevisa el registro de actividad."
        }
    }
    catch {

        $exito = $false

        $mensajeFinal =
            "Ocurrió un error durante la ejecución:`n`n$($_.Exception.Message)"

        Escribir-Log `
            $_.Exception.Message `
            "ERROR"
    }


    # ========================================================
    # GUARDAR RESULTADO
    # ========================================================

    $script:ProcesoExitoso =
        $exito

    $script:ProcesoCompletado =
        $true


    # ========================================================
    # LIMPIEZA
    #
    # IMPORTANTE:
    # Se realiza ANTES de mostrar el MessageBox.
    # ========================================================

    $script:EstadoProceso =
        "LIMPIANDO"


    Limpiar-Runspace


    # ========================================================
    # RESTABLECER INTERFAZ
    # ========================================================

    Cambiar-Controles $true


    # ========================================================
    # ACTUALIZAR ESTADO FINAL
    # ========================================================

    if ($exito) {

        Actualizar-Estado `
            "Proceso completado correctamente." `
            100
    }
    else {

        Actualizar-Estado `
            "Proceso detenido por error." `
            0
    }


    # ========================================================
    # AHORA SÍ ESTÁ COMPLETAMENTE INACTIVO
    # ========================================================

    $script:EstadoProceso =
        "INACTIVO"


    # ========================================================
    # PREPARAR SIGUIENTE USUARIO
    # ========================================================

    if ($exito) {

        $txtUsuario.Text =
            Obtener-SiguienteUsuario
    }


    # ========================================================
    # MOSTRAR UNA SOLA NOTIFICACIÓN
    # ========================================================

    if (
        -not $script:NotificacionMostrada
    ) {

        $script:NotificacionMostrada =
            $true

        if ($exito) {

            [System.Windows.Forms.MessageBox]::Show(
                $mensajeFinal,
                "Proceso completado",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {

            [System.Windows.Forms.MessageBox]::Show(
                $mensajeFinal,
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
})


# ============================================================
# CERRAR FORMULARIO
# ============================================================

$form.Add_FormClosing({

    # ========================================================
    # SI ESTÁ INACTIVO
    #
    # Se puede cerrar directamente.
    # ========================================================

    if (
        $script:EstadoProceso -eq "INACTIVO"
    ) {

        return
    }


    # ========================================================
    # SI ESTÁ EJECUTANDO
    # ========================================================

    $resultado =
        [System.Windows.Forms.MessageBox]::Show(
            "Hay un proceso de preparación ejecutándose.`n`n¿Realmente deseas cerrar la herramienta?",
            "Proceso en ejecución",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )


    if (
        $resultado `
        -eq `
        [System.Windows.Forms.DialogResult]::No
    ) {

        $_.Cancel =
            $true

        return
    }


    # ========================================================
    # CANCELAR EJECUCIÓN
    # ========================================================

    $timer.Stop()


    $script:EstadoProceso =
        "CANCELANDO"


    Limpiar-Runspace


    $script:EstadoProceso =
        "INACTIVO"
})


# ============================================================
# MOSTRAR FORMULARIO
# ============================================================

[void]$form.ShowDialog()