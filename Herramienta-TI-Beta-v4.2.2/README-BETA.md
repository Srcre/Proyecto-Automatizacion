# Herramienta de TI - Beta V4.2.2

Esta carpeta contiene la versión congelada de la GUI estable V4.2.2 del proyecto.

## Archivos

- `PREPARAR-PC-BETA-v4.2.2.ps1`: copia congelada del script estable.
- `COMPILAR-BETA.ps1`: script para generar el `.exe`.
- `Herramienta-TI-Beta-v4.2.2.exe`: se generará al compilar en Windows.

## Compilación

La compilación debe realizarse en Windows PowerShell 5.1.

Abrir PowerShell como Administrador y ejecutar:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Después:

```powershell
cd "RUTA\Herramienta-TI-Beta-v4.2.2"
.\COMPILAR-BETA.ps1
```

El compilador instala/carga `PS2EXE` y genera:

```text
Herramienta-TI-Beta-v4.2.2.exe
```

## Parámetros de compilación

La beta se compila como:

- `x64`
- `STA`
- `noConsole`
- `requireAdmin`
- versión `4.2.2.0`

`noConsole` evita que aparezca una ventana de consola detrás de la GUI.

`STA` es apropiado para Windows Forms.

`requireAdmin` hace que Windows solicite elevación UAC al iniciar la aplicación.

## Importante

Empaquetar el `.ps1` como `.exe` no convierte PowerShell en otro lenguaje. PS2EXE genera un ejecutable que aloja el script PowerShell. La documentación oficial de PS2EXE describe este comportamiento y sus parámetros de compilación.

La beta debe probarse en una máquina de laboratorio antes de distribuirla.

## Pruebas mínimas de Beta

1. Ejecutar el `.exe`.
2. Confirmar UAC.
3. Confirmar que aparece la GUI.
4. Crear usuario.
5. Configurar usuario estándar.
6. Configurar administrador.
7. Configurar contraseña.
8. Ejecutar WinRM.
9. Ejecutar Firewall.
10. Ejecutar verificación.
11. Ejecutar una segunda vez.
12. Cerrar y volver a abrir la aplicación.
13. Comprobar que no aparece consola.
14. Confirmar que no aparecen falsos errores al terminar.

## Nota de seguridad

La beta utiliza la lógica de laboratorio de V4.2.2. No debe considerarse todavía una versión de producción.

WinRM/TCP 5985 no debe exponerse indiscriminadamente a Internet.
