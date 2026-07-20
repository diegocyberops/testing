# Configuración Endurecida - redis.conf

```conf
#########################################
# RED
#########################################

bind 127.0.0.1 10.10.0.15
protected-mode yes

port 6379

tcp-backlog 511

timeout 300

tcp-keepalive 300

#########################################
# GENERAL
#########################################

daemonize yes
supervised systemd

pidfile /var/run/redis_6379.pid

loglevel notice

logfile /var/log/redis/redis.log

databases 16

#########################################
# AUTENTICACIÓN
#########################################

# Redis 6+
aclfile /etc/redis/users.acl

#########################################
# PERSISTENCIA
#########################################

save 900 1
save 300 10
save 60 10000

stop-writes-on-bgsave-error yes

rdbcompression yes
rdbchecksum yes

dbfilename dump.rdb

dir /var/lib/redis

#########################################
# MEMORIA
#########################################

maxmemory 2gb

maxmemory-policy allkeys-lru

#########################################
# APPEND ONLY
#########################################

appendonly yes

appendfsync everysec

#########################################
# SLOW LOG
#########################################

slowlog-log-slower-than 10000
slowlog-max-len 256

#########################################
# CLIENTES
#########################################

maxclients 2000

#########################################
# TLS
#########################################

tls-port 6379

port 0

tls-cert-file /etc/redis/tls/server.crt
tls-key-file /etc/redis/tls/server.key
tls-ca-cert-file /etc/redis/tls/ca.crt

#########################################
# HARDENING DE COMANDOS
#########################################

rename-command FLUSHALL ""
rename-command FLUSHDB ""
rename-command CONFIG ""
rename-command DEBUG ""
rename-command SHUTDOWN ""
rename-command KEYS ""
```

---

# Justificación del Hardening

## 1. Restricción de interfaces de red

Redis deja de escuchar en todas las interfaces y únicamente acepta conexiones desde la dirección privada de la VPC y la interfaz local.

Esto reduce significativamente la superficie de exposición.

---

## 2. Protected Mode

Se habilitó `protected-mode` para impedir conexiones externas cuando Redis no esté correctamente autenticado.

---

## 3. Autenticación mediante ACL

Se reemplazó el uso tradicional de `requirepass` por ACL, disponibles desde Redis 6.

Esto permite gestionar múltiples usuarios con permisos diferenciados y aplicar el principio de mínimo privilegio.

---

## 4. Cifrado de comunicaciones

Se habilitó TLS para proteger la confidencialidad e integridad del tráfico entre Redis y las aplicaciones.

En caso de utilizar una VPN con cifrado robusto y controles de acceso estrictos, TLS podría considerarse opcional por razones de rendimiento, pero su uso proporciona una capa adicional de seguridad.

---

## 5. Directorio seguro de persistencia

Se reemplazó `/tmp` por `/var/lib/redis`, evitando el uso de un directorio temporal compartido.

---

## 6. Control del consumo de memoria

Se estableció un límite máximo de memoria para evitar que Redis consuma todos los recursos del servidor.

La política `allkeys-lru` permite eliminar las claves menos utilizadas, manteniendo la disponibilidad del servicio de caché.

---

## 7. Persistencia

Se habilitó AOF (`appendonly yes`) para mejorar la recuperación de datos tras un fallo del sistema sin afectar significativamente el rendimiento gracias a `appendfsync everysec`.

---

## 8. Protección de comandos administrativos

Se deshabilitaron comandos de administración que podrían ser utilizados para borrar datos, modificar la configuración o detener el servicio en caso de compromiso.

---

## 9. Gestión de conexiones

Se configuró un tiempo de expiración para conexiones inactivas y se ajustó el número máximo de clientes a un valor coherente con la capacidad esperada del servidor.

---

# Impacto sobre la disponibilidad

Las medidas de hardening fueron seleccionadas para mantener el equilibrio entre seguridad y operación:

- La política `allkeys-lru` evita rechazar nuevas escrituras cuando la memoria alcanza su límite, favoreciendo el funcionamiento continuo del sistema de caché y del mecanismo de rate limiting.
- El límite de memoria protege al servidor frente al agotamiento de recursos sin comprometer el rendimiento habitual.
- La habilitación de TLS incrementa ligeramente el consumo de CPU, pero mejora la protección de los datos en tránsito.
- La autenticación mediante ACL fortalece el control de acceso sin afectar el funcionamiento normal de las aplicaciones autorizadas.
- La restricción de interfaces y la desactivación de comandos administrativos reducen la superficie de ataque sin impactar las operaciones legítimas del servicio.
```