# ============================================================
# COMPILADOR DE LA BETA
# HERRAMIENTA DE TI - V4.2.2
#
# Ejecutar desde Windows PowerShell 5.1 como Administrador.
# Este script NO modifica la logica de la herramienta.
# Solo prepara y compila la copia congelada de V4.2.2.
# ============================================================

$ErrorActionPreference = "Stop"

$carpeta = Split-Path -Parent $MyInvocation.MyCommand.Path

$entrada = Join-Path $carpeta "PREPARAR-PC-BETA-v4.2.2.ps1"
$salida = Join-Path $carpeta "Herramienta-TI-Beta-v4.2.2.exe"

Write-Host ""
Write-Host "==============================================="
Write-Host " HERRAMIENTA DE TI - COMPILACION BETA"
Write-Host " Version 4.2.2"
Write-Host "==============================================="
Write-Host ""

# ------------------------------------------------------------
# Validar archivo fuente
# ------------------------------------------------------------

if (-not (Test-Path $entrada)) {
    throw "No se encontro el archivo fuente: $entrada"
}

Write-Host "[OK] Archivo fuente encontrado."
Write-Host "[INFO] Fuente: $entrada"

# ------------------------------------------------------------
# Instalar/cargar PS2EXE
# ------------------------------------------------------------

if (-not (Get-Module -ListAvailable -Name ps2exe)) {

    Write-Host "[INFO] PS2EXE no esta instalado."
    Write-Host "[INFO] Instalando PS2EXE para el usuario actual..."

    Install-Module `
        -Name ps2exe `
        -Scope CurrentUser `
        -Force `
        -AllowClobber
}

Import-Module ps2exe -Force

Write-Host "[OK] PS2EXE cargado."

# ------------------------------------------------------------
# Mostrar version de PS2EXE
# ------------------------------------------------------------

$modulo = Get-Module ps2exe

if ($modulo) {
    Write-Host "[INFO] PS2EXE version: $($modulo.Version)"
}

# ------------------------------------------------------------
# Eliminar EXE anterior
# ------------------------------------------------------------

if (Test-Path $salida) {

    Write-Host "[INFO] Eliminando EXE anterior..."

    Remove-Item `
        -Path $salida `
        -Force
}

# ------------------------------------------------------------
# Compilar
# ------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Compilando V4.2.2..."
Write-Host ""

Invoke-PS2EXE `
    -InputFile $entrada `
    -OutputFile $salida `
    -x64 `
    -STA `
    -noConsole `
    -requireAdmin `
    -title "Herramienta de TI" `
    -description "Herramienta de soporte TI - Beta V4.2.2" `
    -company "Proyecto Automatizacion" `
    -product "Herramienta de TI" `
    -version "4.2.2.0"

# ------------------------------------------------------------
# Validar resultado
# ------------------------------------------------------------

if (-not (Test-Path $salida)) {
    throw "La compilacion termino pero no se encontro el EXE."
}

$archivo = Get-Item $salida

Write-Host ""
Write-Host "==============================================="
Write-Host "[OK] COMPILACION COMPLETADA"
Write-Host "==============================================="
Write-Host ""
Write-Host "EXE:"
Write-Host $archivo.FullName
Write-Host ""
Write-Host "Tamano:"
Write-Host "$([math]::Round($archivo.Length / 1KB, 2)) KB"
Write-Host ""
Write-Host "Version: 4.2.2.0"
Write-Host ""
Write-Host "IMPORTANTE:"
Write-Host "Esta es una copia beta congelada de V4.2.2."
Write-Host "No reemplazar el archivo fuente original."
Write-Host ""
