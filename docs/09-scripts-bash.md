# 09 — Scripts Bash

> **Estado:** Scripts implementados en `scripts/` · Despliegue y pruebas pendientes
> **Responsable:** José (scripts de `app-server` y `bdd-server`) · Luis (revisión y receptor en `zabbix-server`)

## Convenciones generales

Todo script entregado en este proyecto sigue las mismas convenciones:

### Cabecera estándar

```
# =============================================================================
# Script:      <nombre>.sh
# Propósito:   <descripción breve>
# Servidor:    <donde corre> (<IP>)
# Grupo:       José (1077222) y Luis (1227421)
# Curso:       Sistemas Operativos - URL 2026
# Uso:         <invocación>
# =============================================================================
```

### Estructura

1. Shebang `#!/usr/bin/env bash`.
2. Cabecera de documentación (arriba).
3. `set -euo pipefail` — sale al primer error, marca como error usar variables
   no definidas, propaga errores en pipes.
4. Carga de funciones comunes con `source` desde `scripts/lib/common.sh`.
5. Bloque de configuración (variables sobrescribibles vía entorno).
6. Validaciones de prerrequisitos (`require_cmd`).
7. Cuerpo del script.

### Salidas

- Todos los archivos de salida van a `/var/log/so-project/`.
- Los CSV incluyen encabezado en la primera línea, escrito solo si el
  archivo aún no existe.
- Los logs operativos del propio script (no los datos) van al stderr,
  decorados con `timestamp()`.

### Manejo de SSH/SCP

- Siempre con `-o BatchMode=yes` para que el script falle rápido si no hay
  llave (en vez de quedar esperando contraseña).
- Siempre con `-o ConnectTimeout=5` para acotar el tiempo en red caída.
- Las funciones helpers viven en `scripts/lib/common.sh`
  (`file_exists_on_remote`, `log`, `timestamp`).

## Descripción funcional de cada script

### `app-server/listar-conexiones-red.sh`

Captura las conexiones TCP en estado `ESTABLISHED` del propio `app-server`
y las graba en `/var/log/so-project/conexiones-establecidas.log`. Una línea
por conexión, con formato CSV:
`TIMESTAMP, PROTOCOLO, LOCAL:PORT, REMOTE:PORT, ESTADO, PROCESO`.

Usa la herramienta `ss` (no `netstat`, que está deprecated en distros
recientes). Cada ejecución **anexa** al archivo, formando un histórico
útil para revisar a posteriori qué clientes se conectaron y a qué hora.

### `app-server/estado-servicio-bdd.sh`

Consulta vía SSH al `bdd-server` el estado del servicio `mariadb` y graba
una línea CSV por ejecución en `/var/log/so-project/estado-bdd.csv` con
formato `timestamp, servicio, estado, sub_estado`. Cubre el requisito
explícito del enunciado: "una línea por cada lectura que tenga la fecha-
hora y valores obtenidos, separados por coma".

Valores típicos:

| `estado` | `sub_estado` | Interpretación |
|---|---|---|
| `active` | `running` | Servicio operando normalmente |
| `inactive` | `dead` | Servicio detenido |
| `failed` | `failed` | Servicio falló al iniciar |
| `unreachable` | `n/a` | No se pudo contactar al servidor |

### `app-server/recursos-bdd.sh`

Consulta CPU y memoria del `bdd-server` (vía SSH usando `top -bn2` y
`free -m`) y graba el resultado en `/var/log/so-project/recursos-bdd.csv`
con formato `timestamp, cpu_pct, mem_usada_mb, mem_total_mb, mem_pct`.

Después de escribir localmente, **traslada el archivo al `zabbix-server`**,
cumpliendo el requisito del enunciado: "el archivo de texto se debe
trasladar hacia el servidor Zabbix luego de ser generado, y el script
debe revisar si el archivo ya existe previo a intentar trasladarlo".

La lógica de traslado: si el archivo del día ya existe en Zabbix, solo se
**anexa la nueva línea** vía SSH (no se reenvía todo el archivo). Si no
existe, se transfiere completo con `scp`. Esto evita tráfico innecesario y
es robusto ante reinicios.

### `bdd-server/backup-bdd.sh`

Genera el backup diario de la BDD con `mariadb-dump --single-transaction`
para no bloquear tablas InnoDB durante el dump. El archivo se comprime con
`gzip` en una sola pipeline y se nombra `tienda-<timestamp>.sql.gz`.

Validaciones críticas implementadas:

1. **El backup no puede aterrizar en el mismo disco que los datos.** El
   script compara los dispositivos de bloque de `/var/lib/mysql` (o donde
   esté el datadir) y `/mnt/backups`. Si coinciden, aborta con error. Esto
   cumple literalmente el requisito: "el backup se traslada hacia un disco
   distinto al usado para alojar los archivos de datos".
2. **El archivo no puede quedar vacío.** Tras generar, se valida tamaño > 0.
3. **Verificación de existencia previa en destino remoto** antes de
   transferir.
4. **Política de retención local:** se eliminan backups locales con más de
   7 días.

El backup se replica vía `scp` hacia `app-server:/var/backups/tienda/`,
cumpliendo "trasladar los archivos de backup hacia cualquier otro servidor".

### `lib/common.sh`

Biblioteca de funciones reutilizables:

| Función | Propósito |
|---|---|
| `timestamp` | Devuelve fecha-hora actual `YYYY-MM-DD HH:MM:SS` |
| `timestamp_compact` | Variante sin separadores, para nombres de archivo |
| `log <msg>` | Imprime mensaje con timestamp al stderr |
| `require_cmd <cmd>` | Aborta si un comando no está instalado |
| `file_exists_on_remote <user@host> <path>` | Verifica existencia de archivo remoto vía SSH |

## Despliegue

Los scripts se copian a `/opt/so-project/scripts/` del servidor
correspondiente, manteniendo la estructura `app-server/`, `bdd-server/`
y `lib/`. Permisos `0755`, propietario `urlos:urlos`. El directorio
de logs `/var/log/so-project/` se crea con los mismos permisos.

## Por completar tras implementación

- [ ] Salida de ejecución manual de cada script (primer corrida).
- [ ] Captura del CSV generado por `estado-servicio-bdd.sh` con varias líneas.
- [ ] Captura del CSV generado por `recursos-bdd.sh` con varias líneas.
- [ ] Confirmación de que el archivo aparece en `zabbix-server` (`ls -la`).
- [ ] Salida exitosa de `backup-bdd.sh` mostrando archivo creado en
      `/mnt/backups` y replicado en `app-server`.