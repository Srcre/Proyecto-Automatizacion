# Proyecto Automatización

## PREPARAR-PC.ps1

Script de laboratorio para preparar un equipo Windows para administración remota mediante PowerShell Remoting/WinRM y crear una cuenta local de prueba.

> **Advertencia:** este proyecto usa la contraseña fija `prueba` únicamente para pruebas. No usar estas credenciales en equipos reales o en producción.

---

## 1. Objetivo

El script automatiza estas tareas:

1. Comprueba que PowerShell se esté ejecutando como Administrador.
2. Configura PowerShell Remoting mediante `Enable-PSRemoting`.
3. Configura el servicio WinRM para iniciarse automáticamente.
4. Busca el siguiente nombre de usuario disponible:
   - `prueba`
   - `prueba1`
   - `prueba2`
   - `prueba3`
   - etc.
5. Crea el usuario con contraseña `prueba`.
6. Pregunta qué nivel de privilegios se desea:
   - Usuario estándar
   - Administrador
7. Agrega la cuenta al grupo local correspondiente.
8. Comprueba que la cuenta y WinRM hayan quedado configurados.

---

## 2. Estructura actual

```text
Proyecto-Automatizacion/
│
├── PREPARAR-PC.ps1
└── README.md
```

---

## 3. Requisitos

- Windows con PowerShell.
- Ejecutar VS Code/PowerShell como Administrador.
- El módulo `Microsoft.PowerShell.LocalAccounts` debe estar disponible para los comandos `Get-LocalUser`, `New-LocalUser` y `Add-LocalGroupMember`.

---

## 4. Cómo ejecutar

Abrir PowerShell como Administrador y ubicarse en la carpeta:

```powershell
cd "C:\ruta\Proyecto-Automatizacion"
```

Comprobar que el archivo existe:

```powershell
Test-Path .\PREPARAR-PC.ps1
```

Resultado esperado:

```text
True
```

Ejecutar:

```powershell
.\PREPARAR-PC.ps1
```

---

# Registro de problemas encontrados

## Problema 1: `powershell` no reconocido

### Síntoma

El script comenzó con un error similar a:

```text
The term 'powershell' is not recognized as a name of a cmdlet...
```

### Causa

El archivo `.ps1` contenía accidentalmente la línea de apertura de un bloque de código Markdown:

```text
```powershell
```

Esa línea sirve para mostrar código en un documento/chat, pero **no forma parte del script de PowerShell**.

### Solución

El archivo `.ps1` debe comenzar directamente con:

```powershell
# ==========================================
# PREPARAR-PC.ps1
```

y NO con:

```text
```powershell
```

También debe terminar sin una línea:

```text
```
```

---

## Problema 2: descripción demasiado larga

### Síntoma

`New-LocalUser` mostró:

```text
Cannot validate argument on parameter 'Description'.
The character length ... is too long.
```

### Causa

La descripción proporcionada superaba el límite permitido por `New-LocalUser`.

### Solución

Se redujo a:

```powershell
-Description "Cuenta de prueba para administracion remota"
```

---

## Problema 3: el script continuó aunque `New-LocalUser` falló

### Síntoma

Aunque `New-LocalUser` falló, el script continuó mostrando:

```text
[OK] Usuario prueba creado.
```

Después falló:

```text
Add-LocalGroupMember
```

porque la cuenta realmente no existía.

### Causa

Muchos errores de PowerShell son errores no terminantes. Sin una configuración adecuada, el script puede continuar después de un comando que falló.

### Solución

Los comandos críticos ahora utilizan:

```powershell
-ErrorAction Stop
```

y están dentro de bloques:

```powershell
try {
    ...
}
catch {
    ...
}
```

Así, si la creación falla, el script **no continúa como si todo hubiera salido bien**.

---

## Problema 4: `prueba` no se encontró al agregarla al grupo

### Síntoma

Apareció:

```text
No se encontró la entidad de seguridad prueba.
```

### Causa

Era una consecuencia del problema anterior. El usuario `prueba` nunca se había creado correctamente debido al error de `Description`.

### Solución

Ahora la creación de la cuenta se valida antes de continuar.

Además, si falla la asignación del grupo, el script intenta eliminar la cuenta creada para evitar dejar una configuración incompleta.

---

## Problema 5: nombres de grupos según idioma de Windows

Windows puede mostrar los grupos integrados con nombres diferentes según el idioma:

```text
Administrators
Users
```

o:

```text
Administradores
Usuarios
```

### Solución

El script no depende directamente del nombre en inglés.

Busca los grupos mediante sus SID conocidos:

```text
S-1-5-32-544 → Administradores / Administrators
S-1-5-32-545 → Usuarios / Users
```

Después obtiene el nombre real del grupo instalado en el equipo.

Esto hace que el script sea más compatible con Windows en distintos idiomas.

---

# 5. Lógica de creación progresiva

El script revisa los nombres existentes.

Ejemplo:

```text
prueba       → existe
prueba1      → existe
prueba2      → no existe
```

Entonces crea:

```text
prueba2
```

Si posteriormente `prueba1` se elimina:

```text
prueba       → existe
prueba1      → libre
```

la siguiente ejecución reutilizará:

```text
prueba1
```

El contador no se almacena en ningún archivo. Se determina mirando las cuentas existentes.

---

# 6. Selección de privilegios

Después de crear la cuenta aparece:

```text
[1] Usuario estandar
[2] Administrador
```

### Opción 1

La cuenta se agrega al grupo local:

```text
Users / Usuarios
```

### Opción 2

La cuenta se agrega al grupo local:

```text
Administrators / Administradores
```

---

# 7. Credenciales actuales del laboratorio

```text
Usuario:
prueba / prueba1 / prueba2 / ...

Contraseña:
prueba
```

Estas credenciales son **solo para el laboratorio**.

Para una versión destinada a equipos reales habrá que reemplazar esta contraseña fija por un método seguro.

---

# 8. Próximos pasos del proyecto

## Paso 3 actual

- [x] Crear script `.ps1`
- [x] Crear usuarios progresivamente
- [x] Elegir privilegios
- [x] Configurar WinRM
- [x] Manejar errores
- [x] Compatibilidad con grupos localizados
- [x] Documentar errores

## Próxima etapa

Antes de utilizar este script en equipos reales:

1. Probar creación de usuario estándar.
2. Probar creación de administrador.
3. Ejecutar varias veces para comprobar `prueba`, `prueba1`, `prueba2`, etc.
4. Comprobar los grupos de cada cuenta.
5. Comprobar WinRM.
6. Probar conexión remota desde el equipo de soporte.
7. Revisar firewall y restricciones de acceso.
8. Eliminar la contraseña fija del código.
9. Diseñar una configuración segura para equipos remotos expuestos a Internet.

## ERROR: No se puede quitar el último administrador

### Modulo
Contrasena.ps1

### Operacion

Set-LocalUser -Name "prueba" -UserMayChangePassword $false

### Resultado

Windows devuelve:

No se puede quitar el último administrador

### Diagnostico

La operacion fue ejecutada directamente con Set-LocalUser,
sin utilizar el modulo de automatizacion.

El mismo error fue reproducido directamente por Windows.

Por lo tanto, el error no es causado por la logica del modulo.

### Comportamiento del modulo

El modulo no debe intentar eliminar, mover o degradar automaticamente
la cuenta administrativa para evitar el error.

Debe capturar la excepcion y devolver un resultado controlado:

Estado = WARNING

Esto permite que otras configuraciones de la cuenta puedan continuar.

### Leccion

Las operaciones de configuracion de una cuenta deben ser independientes.

Una restriccion de Windows sobre UserMayChangePassword no debe impedir
que PasswordNeverExpires, permisos u otras configuraciones validas
puedan ejecutarse.

---

## ERROR: Usuario no encontrado

### Operacion

Set-LocalUser -Name "prueba1" -UserMayChangePassword $false

### Resultado

Windows devuelve:

No se encontro el usuario prueba1.

### Causa

La cuenta prueba1 no existe actualmente en el equipo.

### Solucion

El modulo debe verificar la existencia del usuario antes de intentar
modificarlo y devolver un ERROR controlado si no existe.