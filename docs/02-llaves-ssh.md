# 02 — Llaves SSH

> **Estado:** Diseño completado · Implementación pendiente
> **Responsable:** Ambos (cada quien genera su llave)

## Algoritmo

Se usa **Ed25519** sobre RSA por tres razones: llaves más cortas (mejor
manejabilidad), criptografía moderna basada en curvas elípticas, y
rendimiento superior en autenticación. La forma de generación es la estándar
con un comentario identificador.

## Inventario de llaves

| Llave | Generada en | Comentario | Propósito |
|---|---|---|---|
| `id_ed25519` de Laptop A | Laptop del evaluador | `lap-a-admin` | Acceso administrativo a las 4 VMs |
| `id_ed25519` de José | Laptop José | `jose-1077222` | Acceso a las VMs hosteadas por Luis |
| `id_ed25519` de Luis | Laptop Luis | `luis-1227421` | Acceso a las VMs hosteadas por José |
| `id_ed25519` interna en `app-server` | VM app-server | `app-to-bdd` | SSH/SCP de app-server hacia bdd y zabbix (para scripts) |
| `id_ed25519` interna en `bdd-server` | VM bdd-server | `bdd-to-app` | SCP del backup hacia app-server |

Las llaves **privadas** nunca salen de su máquina de origen ni se suben al
repositorio (cubiertas por `.gitignore`). Solo las públicas (`.pub`) se
distribuyen.

## Matriz de acceso esperada

| Origen ↓ \\ Destino → | `bdd` | `app` | `elk` | `zabbix` |
|---|---|---|---|---|
| Laptop A | ✓ | ✓ | ✓ | ✓ |
| Laptop José | ✗ (hostea) | ✗ (hostea) | ✓ | ✓ |
| Laptop Luis | ✓ | ✓ | ✗ (hostea) | ✗ (hostea) |
| `app-server` | ✓ (scripts) | — | — | ✓ (scp recursos) |
| `bdd-server` | — | ✓ (scp backup) | — | — |

Los "✗ (hostea)" se imponen por **firewall UFW**, no por ausencia de llave.
Ver `docs/03-firewall-ufw.md`.

## Endurecimiento del servicio SSH

Tras verificar que la autenticación por llave funciona en cada VM, se aplican
los siguientes cambios en `/etc/ssh/sshd_config`:

- `PasswordAuthentication no` — elimina la posibilidad de login por contraseña.
- `PermitRootLogin no` — root no puede entrar por SSH.
- `PubkeyAuthentication yes` — explícito, aunque ya es el default.
- `AllowUsers urlos` — solo el usuario administrativo puede entrar.

## Alias en `~/.ssh/config` de Laptop A

Para que los comandos sean breves (`ssh bdd` en vez de IPs):

```
Host bdd
    HostName 192.168.8.20
    User urlos
    IdentityFile ~/.ssh/id_ed25519

Host app
    HostName 192.168.8.21
    User urlos
    IdentityFile ~/.ssh/id_ed25519

Host elk
    HostName 192.168.8.22
    User urlos
    IdentityFile ~/.ssh/id_ed25519

Host zabbix
    HostName 192.168.8.23
    User urlos
    IdentityFile ~/.ssh/id_ed25519
```

Los mismos alias se replican en los hosts `app-server` y `bdd-server` (con
las llaves internas correspondientes) para que los scripts puedan invocar
`ssh bdd-server` o `ssh zabbix-server` sin codificar IPs.

## Por completar tras implementación

- [ ] Salida de `ssh-keygen` mostrando la huella de cada llave generada.
- [ ] Captura de un login exitoso por llave (sin solicitud de contraseña).
- [ ] Captura de un intento fallido tras desactivar `PasswordAuthentication`.
- [ ] Contenido final de `~/.ssh/config` en Laptop A.