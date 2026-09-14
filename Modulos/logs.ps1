function Write-LocalPreparationLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Estado,
        [Parameter(Mandatory = $true)]
        [string]$Modulo,
        [string]$Usuario = "",
        [int]$Codigo = 0,
        [Parameter(Mandatory = $true)]
        [string]$Mensaje
    )
    try {
        # --------------------------------------------------------
        # 1. Determinar carpeta de Logs
        # --------------------------------------------------------
        $RutaLogs = Join-Path $PSScriptRoot "..\logs"

        if (-not (Test-Path $RutaLogs)) {
            New-Item `
            -Path $RutaLogs `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop | Out-Null
        }
        # --------------------------------------------------------
        # 2. Determinar archivo diario
        # --------------------------------------------------------
        $FechaActual = Get-date

        $NombreArchivo = "Preparar-PC-{0}.log" -f (
        $FechaActual.ToString("yyyy-MM-dd")
        )

        $RutaArchivo = Join-Path `
            $RutaLogs `
            $NombreArchivo
        
        # --------------------------------------------------------
        # 3. Construir registro
        # --------------------------------------------------------

        $Linea = "{0} | {1} | {2} | {3} | {4} | {5}" -f (

            $FechaActual.ToString("yyyy-MM-dd HH:mm:ss"),
            $Modulo,
            $Estado,
            $Usuario,
            $Codigo,
            $Mensaje
        )
        
        # --------------------------------------------------------
        # 4. Escribir registro
        # --------------------------------------------------------

        Add-Content `
            -Path $RutaArchivo `
            -Value $Linea `
            -Encoding UTF8 `
            -ErrorAction Stop

        # --------------------------------------------------------
        # 5. Resultado estructurado
        # --------------------------------------------------------

        return [PSCustomObject]@{
            Estado = "SUCCESS"
            Usuario = $Usuario
            Mensaje = "Registro agregado correctamente"
            Codigo = 0
            Archivo = $NombreArchivo
            Ruta = $RutaArchivo
        }
    }
    catch {
        return [PSCustomObject]@{
            Estado = "ERROR"
            Usuario = $Usuario
            Mensaje = "Error al escribir el log: $($_.Exception.Message)"
            Codigo = 99
            Archivo = ""
            Ruta = ""
        }
    }
}


function Get-LocalPreparationLog {
    [CmdletBinding()]
    param(
        [string]$NombreArchivo,
        [string]$NombreModulo,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Estado,
        [string]$NombreUsuario,
        [datetime]$FechaInicio,
        [datetime]$FechaFin,
        [string]$TextoBusqueda
    )
    try {
        # ------------------------------------------------------------
        # 1. Validar carpeta de Logs
        # ------------------------------------------------------------
        $RutaLogs = Join-Path $PSScriptRoot "..\Logs"
        if (-not (Test-Path $RutaLogs)) {
            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = ""
                Mensaje = "La carpeta de Logs no existe."
                Codigo  = 1
            }
        }


        # ------------------------------------------------------------
        # 2. Obtener archivos de log
        # ------------------------------------------------------------
        if ($NombreArchivo) {
            $RutaArchivo = Join-Path $RutaLogs $NombreArchivo
            if (-not (Test-Path $RutaArchivo)) {
                return [PSCustomObject]@{
                    Estado  = "WARNING"
                    Usuario = ""
                    Mensaje = "El archivo de log '$NombreArchivo' no existe."
                    Codigo  = 2
                }
            }
            $Archivos = @(Get-Item $RutaArchivo)
        }
        else {
            $Archivos = @(Get-ChildItem `
                -Path $RutaLogs `
                -Filter "Preparar-PC-*.log" `
                -File)
        }


        # ------------------------------------------------------------
        # 3. Verificar que existan archivos
        # ------------------------------------------------------------

        if ($Archivos.Count -eq 0) {
            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = ""
                Mensaje = "No existen archivos de log para consultar."
                Codigo  = 3
            }
        }


        # ------------------------------------------------------------
        # 4. Leer y procesar registros
        # ------------------------------------------------------------

        $Resultados = @()
        foreach ($Archivo in $Archivos) {
            $Lineas = Get-Content -Path $Archivo.FullName
            foreach ($Linea in $Lineas) {
                if ([string]::IsNullOrWhiteSpace($Linea)) {
                    continue
                }


                # ----------------------------------------------------
                # 5. Separar campos del registro
                # ----------------------------------------------------
                $Partes = $Linea -split '\s*\|\s*', 6
                if ($Partes.Count -lt 6) {
                    continue
                }
                $FechaHoraTexto = $Partes[0]
                $Modulo         = $Partes[1]
                $EstadoRegistro = $Partes[2]
                $Usuario        = $Partes[3]
                $Codigo         = $Partes[4]
                $Mensaje        = $Partes[5]
                # ----------------------------------------------------
                # 6. Convertir fecha
                # ----------------------------------------------------
                try {
                    $FechaHora = [datetime]::ParseExact(
                        $FechaHoraTexto,
                        "yyyy-MM-dd HH:mm:ss",
                        $null
                    )
                }
                catch {
                    continue
                }


                # ----------------------------------------------------
                # 7. Crear objeto estructurado
                # ----------------------------------------------------
                $Registro = [PSCustomObject]@{
                    FechaHora = $FechaHora
                    Modulo    = $Modulo
                    Estado    = $EstadoRegistro
                    Usuario   = $Usuario
                    Codigo    = $Codigo
                    Mensaje   = $Mensaje
                    Archivo   = $Archivo.Name
                }


                # ----------------------------------------------------
                # 8. Filtro por módulo
                # ----------------------------------------------------
                if ($NombreModulo) {
                    if ($Registro.Modulo -notlike "*$NombreModulo*") {
                        continue
                    }
                }


                # ----------------------------------------------------
                # 9. Filtro por estado
                # ----------------------------------------------------
                if ($Estado) {
                    if ($Registro.Estado -ne $Estado) {
                        continue
                    }
                }


                # ----------------------------------------------------
                # 10. Filtro por usuario
                # ----------------------------------------------------
                if ($NombreUsuario) {
                    if ($Registro.Usuario -notlike "*$NombreUsuario*") {
                        continue
                    }
                }


                # ----------------------------------------------------
                # 11. Filtro por fecha inicial
                # ----------------------------------------------------
                if ($FechaInicio) {
                    if ($Registro.FechaHora -lt $FechaInicio) {
                        continue
                    }
                }


                # ----------------------------------------------------
                # 12. Filtro por fecha final
                # ----------------------------------------------------
                if ($FechaFin) {
                    if ($Registro.FechaHora -gt $FechaFin) {
                        continue
                    }
                }


                # ----------------------------------------------------
                # 13. Búsqueda de texto
                # ----------------------------------------------------
                if ($TextoBusqueda) {
                    $Coincide = (
                        $Registro.Modulo   -like "*$TextoBusqueda*" -or
                        $Registro.Usuario  -like "*$TextoBusqueda*" -or
                        $Registro.Codigo   -like "*$TextoBusqueda*" -or
                        $Registro.Mensaje  -like "*$TextoBusqueda*"
                    )
                    if (-not $Coincide) {
                        continue
                    }
                }


                # ----------------------------------------------------
                # 14. Agregar resultado
                # ----------------------------------------------------
                $Resultados += $Registro
            }
        }


        # ------------------------------------------------------------
        # 15. Ordenar resultados
        # ------------------------------------------------------------
        $Resultados = @(
            $Resultados |
            Sort-Object FechaHora
        )
        # ------------------------------------------------------------
        # 16. Devolver resultados
        # ------------------------------------------------------------
        if ($Resultados.Count -eq 0) {
            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = ""
                Mensaje = "No se encontraron registros que coincidan con los filtros."
                Codigo  = 4
            }
        }
        return $Resultados
    }
    catch {
        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = ""
            Mensaje = "Error al consultar los logs: $($_.Exception.Message)"
            Codigo  = 99
        }
    }
}

function Export-LocalPreparationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Registros,
        [Parameter(Mandatory = $true)]
        [ValidateSet("CSV", "JSON", "TXT")]
        [string]$Formato,
        [string]$RutaDestino,
        [string]$NombreArchivo
    )
    try {
        # ------------------------------------------------------------
        # 1. Validar registros
        # ------------------------------------------------------------
        if (-not $Registros -or $Registros.Count -eq 0) {
            return [PSCustomObject]@{
                Estado  = "WARNING"
                Usuario = ""
                Mensaje = "No existen registros para exportar."
                Codigo  = 1
                Archivo = ""
                Ruta    = ""
            }
        }
        # ------------------------------------------------------------
        # 2. Definir carpeta de exportaciones
        # ------------------------------------------------------------
        $RutaLogs = Join-Path $PSScriptRoot "..\Logs"
        if (-not (Test-Path $RutaLogs)) {
            New-Item `
                -Path $RutaLogs `
                -ItemType Directory `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }
        $RutaExportaciones = Join-Path `
            $RutaLogs `
            "Exportaciones"
        if (-not (Test-Path $RutaExportaciones)) {
            New-Item `
                -Path $RutaExportaciones `
                -ItemType Directory `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }
        # ------------------------------------------------------------
        # 3. Determinar ruta destino
        # ------------------------------------------------------------
        if (-not $RutaDestino) {
            $RutaDestino = $RutaExportaciones
        }
        else {
            if (-not (Test-Path $RutaDestino)) {
                New-Item `
                    -Path $RutaDestino `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }
        }


        # ------------------------------------------------------------
        # 4. Determinar nombre del archivo
        # ------------------------------------------------------------
        $MarcaTiempo = Get-Date -Format "yyyy-MM-dd-HHmmss"
        if (-not $NombreArchivo) {
            $NombreArchivo = "Export-Logs-$MarcaTiempo"
        }


        # ------------------------------------------------------------
        # 5. Determinar extensión
        # ------------------------------------------------------------
        switch ($Formato) {
            "CSV" {
                $Extension = ".csv"
            }
            "JSON" {
                $Extension = ".json"
            }
            "TXT" {
                $Extension = ".txt"
            }
        }


        # ------------------------------------------------------------
        # 6. Evitar extensión duplicada
        # ------------------------------------------------------------
        if ($NombreArchivo -notlike "*$Extension") {
            $NombreArchivo = "$NombreArchivo$Extension"
        }
        $RutaArchivo = Join-Path `
            $RutaDestino `
            $NombreArchivo


        # ------------------------------------------------------------
        # 7. Exportar
        # ------------------------------------------------------------
        switch ($Formato) {
            "CSV" {
                $Registros |
                    Export-Csv `
                        -Path $RutaArchivo `
                        -NoTypeInformation `
                        -Encoding UTF8 `
                        -Force
            }
            "JSON" {
                $Registros |
                    ConvertTo-Json `
                        -Depth 5 |
                    Set-Content `
                        -Path $RutaArchivo `
                        -Encoding UTF8
            }
            "TXT" {
                $Registros |
                    Format-Table `
                        FechaHora,
                        Modulo,
                        Estado,
                        Usuario,
                        Codigo,
                        Mensaje,
                        Archivo `
                        -AutoSize |
                    Out-String |
                    Set-Content `
                        -Path $RutaArchivo `
                        -Encoding UTF8
            }
        }


        # ------------------------------------------------------------
        # 8. Verificar creación
        # ------------------------------------------------------------
        if (-not (Test-Path $RutaArchivo)) {
            return [PSCustomObject]@{
                Estado  = "ERROR"
                Usuario = ""
                Mensaje = "La exportación terminó pero el archivo no fue encontrado."
                Codigo  = 2
                Archivo = $NombreArchivo
                Ruta    = $RutaArchivo
            }
        }


        # ------------------------------------------------------------
        # 9. Obtener información del archivo
        # ------------------------------------------------------------
        $ArchivoGenerado = Get-Item $RutaArchivo
        # ------------------------------------------------------------
        # 10. Resultado
        # ------------------------------------------------------------
        return [PSCustomObject]@{
            Estado  = "SUCCESS"
            Usuario = ""
            Mensaje = "Logs exportados correctamente."
            Codigo  = 0
            Archivo = $ArchivoGenerado.Name
            Ruta    = $ArchivoGenerado.FullName
            Formato = $Formato
            Registros = $Registros.Count
        }
    }
    catch {
        return [PSCustomObject]@{
            Estado  = "ERROR"
            Usuario = ""
            Mensaje = "Error al exportar los logs: $($_.Exception.Message)"
            Codigo  = 99
            Archivo = ""
            Ruta    = ""
        }
    }
}