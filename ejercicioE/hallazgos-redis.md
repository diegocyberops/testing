# Revisión de Seguridad - redis.conf

## Resumen Ejecutivo

Se revisó la configuración de Redis utilizada como motor de caché y almacenamiento para el mecanismo de rate limiting de Nimbo Pay. La instancia se encuentra desplegada en una máquina virtual dentro de la VPC, pero también es accesible desde la subred corporativa mediante VPN.

Durante la revisión se identificaron configuraciones que incrementan la superficie de ataque y podrían permitir accesos no autorizados, pérdida de información o indisisponibilidad del servicio.

### Resumen de criticidad

| Severidad | Cantidad |
|-----------|----------|
| 🔴 Crítica | 4 |
| 🟠 Alta | 4 |
| 🟡 Media | 3 |
| 🟢 Baja | 1 |

---

# Hallazgos

---

## 1. Redis escucha en todas las interfaces

**Severidad:** 🔴 Crítica

### Ubicación

```conf
bind 0.0.0.0
```

### Riesgo

Redis acepta conexiones desde cualquier interfaz de red.

Si un firewall o una regla de seguridad es configurada incorrectamente, el servicio quedará expuesto a Internet o a redes no autorizadas.

### Recomendación

Restringir el servicio únicamente a las interfaces privadas utilizadas por la aplicación.

Ejemplo:

```conf
bind 127.0.0.1 10.10.0.15
```

o exclusivamente la IP privada de la VM.

---

## 2. Protected Mode deshabilitado

**Severidad:** 🔴 Crítica

### Ubicación

```conf
protected-mode no
```

### Riesgo

Redis no aplica ninguna protección cuando recibe conexiones externas.

Combinado con `bind 0.0.0.0`, esta configuración representa una de las causas más comunes de exposición pública de Redis.

### Recomendación

```conf
protected-mode yes
```

---

## 3. Autenticación no garantizada

**Severidad:** 🔴 Crítica

### Ubicación

```conf
# requirepass ...
```

### Riesgo

La autenticación depende del script de despliegue y no está definida explícitamente en la configuración.

Un error operacional podría iniciar Redis sin contraseña.

### Recomendación

Implementar autenticación mediante ACL (Redis 6+) o garantizar que `requirepass` sea obligatorio durante el despliegue.

---

## 4. Tráfico sin cifrado

**Severidad:** 🔴 Crítica

### Ubicación

```
Sin configuración TLS
```

### Riesgo

Toda la comunicación entre clientes y Redis viaja en texto plano.

Un atacante con acceso a la red podría capturar:

- credenciales
- sesiones
- claves
- datos en caché

### Recomendación

Habilitar TLS o encapsular el tráfico mediante una red privada segura.

---

## 5. Directorio de persistencia inseguro

**Severidad:** 🟠 Alta

### Ubicación

```conf
dir /tmp
```

### Riesgo

El directorio `/tmp` es compartido por el sistema.

Puede facilitar ataques mediante enlaces simbólicos o acceso no autorizado.

### Recomendación

Utilizar un directorio exclusivo para Redis.

Ejemplo:

```conf
dir /var/lib/redis
```

---

## 6. Sin límite de memoria

**Severidad:** 🟠 Alta

### Ubicación

```conf
maxmemory
```

No configurado.

### Riesgo

Redis utilizará toda la memoria disponible.

Esto puede provocar:

- OOM Killer
- caída del servicio
- indisponibilidad de la aplicación

### Recomendación

Definir un límite adecuado.

Ejemplo:

```conf
maxmemory 2gb
```

---

## 7. Política de memoria inadecuada

**Severidad:** 🟠 Alta

### Ubicación

```conf
maxmemory-policy noeviction
```

### Riesgo

Cuando se llena la memoria, Redis rechaza nuevas escrituras.

Esto puede afectar directamente:

- cache
- rate limiting
- sesiones

### Recomendación

Para un servicio de caché utilizar:

```conf
allkeys-lru
```

---

## 8. Comandos administrativos habilitados

**Severidad:** 🟠 Alta

### Ubicación

```
Todos los comandos disponibles.
```

### Riesgo

Un atacante autenticado puede ejecutar:

- FLUSHALL
- FLUSHDB
- CONFIG
- DEBUG
- SHUTDOWN

Generando pérdida total del servicio.

### Recomendación

Renombrar o deshabilitar comandos administrativos.

---

## 9. Timeout infinito

**Severidad:** 🟡 Media

### Ubicación

```conf
timeout 0
```

### Riesgo

Las conexiones inactivas permanecen abiertas indefinidamente.

Esto favorece el consumo innecesario de recursos.

### Recomendación

Configurar un tiempo razonable.

Ejemplo:

```conf
timeout 300
```

---

## 10. Número excesivo de clientes

**Severidad:** 🟡 Media

### Ubicación

```conf
maxclients 10000
```

### Riesgo

Permite un gran número de conexiones simultáneas.

Puede facilitar ataques de denegación de servicio.

### Recomendación

Definir un valor acorde con la capacidad del servidor.

---

## 11. Logging limitado

**Severidad:** 🟡 Media

### Riesgo

El nivel de log es reducido para auditorías de seguridad.

Puede dificultar investigaciones posteriores.

### Recomendación

Aumentar el nivel durante auditorías o integrar Redis con un SIEM.

---

## 12. Append Only deshabilitado

**Severidad:** 🟢 Baja

### Ubicación

```conf
appendonly no
```

### Riesgo

En caso de fallo del servidor pueden perderse datos recientes.

Para un cache no siempre representa un problema, pero puede afectar mecanismos de rate limiting.

### Recomendación

Evaluar habilitar AOF si la persistencia es un requisito del negocio.

---

# Priorización

| Prioridad | Hallazgo |
|------------|-----------|
| 🔴 | bind 0.0.0.0 |
| 🔴 | protected-mode no |
| 🔴 | Sin autenticación garantizada |
| 🔴 | Sin TLS |
| 🟠 | Directorio /tmp |
| 🟠 | Sin límite de memoria |
| 🟠 | Política noeviction |
| 🟠 | Comandos administrativos |
| 🟡 | timeout infinito |
| 🟡 | maxclients excesivo |
| 🟡 | logging |
| 🟢 | appendonly |