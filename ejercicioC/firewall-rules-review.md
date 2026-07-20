# Auditoría de Seguridad – Reglas de Firewall (`firewall-rules.json`)

## Resumen

Se realizó una revisión de las reglas de firewall configuradas para la VPC **app-vpc** del proyecto **nimbopay-prod**. El análisis identificó configuraciones que exponen servicios críticos directamente a Internet, incrementando significativamente la superficie de ataque. Si bien algunas reglas siguen buenas prácticas, existen exposiciones que podrían facilitar ataques de fuerza bruta, explotación de vulnerabilidades y accesos no autorizados a componentes internos.

---

# Hallazgos

## Hallazgo 1 – Puerto SSH expuesto a Internet

**Severidad:** 🔴 Crítica

### Recurso

```text
Regla: ssh-open-world
```

### Configuración detectada

```json
{
  "sourceRanges": ["0.0.0.0/0"],
  "allowed": [
    {
      "IPProtocol": "tcp",
      "ports": ["22"]
    }
  ]
}
```

### Problema

La regla permite conexiones SSH (TCP/22) desde **cualquier dirección IP de Internet** hacia las instancias etiquetadas como **web-tier**.

### Riesgo

Esta configuración expone los servidores a ataques como:

- Fuerza bruta de credenciales.
- Ataques mediante credenciales filtradas.
- Explotación de vulnerabilidades en el servicio SSH.
- Escaneo automatizado por bots de Internet.

En caso de compromiso de una instancia, un atacante podría obtener acceso inicial a la infraestructura.

### Recomendación

- Restringir el acceso únicamente a direcciones IP administrativas autorizadas.
- Utilizar **Identity-Aware Proxy (IAP)** para administración remota.
- Implementar **OS Login** con autenticación mediante IAM.
- Deshabilitar el acceso SSH público cuando no sea necesario.

---

# Hallazgo 2 – Servicio Redis expuesto públicamente

**Severidad:** 🔴 Crítica

### Recurso

```text
Regla: cache-open-world
```

### Configuración detectada

```json
{
  "sourceRanges": ["0.0.0.0/0"],
  "allowed": [
    {
      "IPProtocol": "tcp",
      "ports": ["6379"]
    }
  ]
}
```

### Problema

El servicio Redis (TCP/6379) es accesible desde cualquier dirección IP de Internet.

### Riesgo

Redis no está diseñado para exponerse públicamente. Esta configuración puede permitir:

- Acceso no autorizado a datos en memoria.
- Manipulación o eliminación de información.
- Ejecución de ataques de denegación de servicio.
- Compromiso del servidor mediante configuraciones inseguras.

La exposición pública de Redis es considerada una mala práctica de seguridad.

### Recomendación

- Limitar el acceso únicamente a las aplicaciones que utilizan Redis.
- Restringir el tráfico mediante rangos IP privados o etiquetas de red.
- Ubicar el servicio en una subred privada sin acceso directo desde Internet.

---

# Hallazgo 3 – Base de datos restringida a red privada

**Severidad:** 🟢 Informativo

### Recurso

```text
Regla: db-internal-only
```

### Configuración detectada

```json
{
  "sourceRanges": [
    "172.16.0.0/12"
  ],
  "ports": [
    "5432"
  ]
}
```

### Observación

El acceso al servicio PostgreSQL se encuentra limitado a un rango de direcciones IP privadas.

### Riesgo

No se identifican exposiciones directas hacia Internet.

Sin embargo, el rango **172.16.0.0/12** puede ser demasiado amplio dependiendo de la arquitectura de la red.

### Recomendación

Reducir el rango de origen al mínimo necesario o utilizar:

- Service Accounts.
- Tags de red.
- Reglas específicas por subnet.
- Controles de segmentación internos.

---

# Hallazgo 4 – Acceso HTTPS restringido al Load Balancer

**Severidad:** 🟢 Informativo

### Recurso

```text
Regla: https-from-lb
```

### Configuración detectada

```json
{
  "sourceRanges": [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ],
  "ports": [
    "443"
  ]
}
```

### Observación

La regla permite conexiones HTTPS únicamente desde los rangos IP utilizados por el Google Cloud Load Balancer.

### Riesgo

No representa un riesgo de seguridad.

Esta configuración reduce la exposición directa de las instancias web y permite que todo el tráfico pase previamente por el balanceador.

### Recomendación

Mantener esta configuración e incorporar mecanismos adicionales como:

- Cloud Armor.
- WAF.
- Protección contra ataques DDoS.
- Políticas de TLS seguras.

---

# Hallazgo 5 – Todas las reglas poseen la misma prioridad

**Severidad:** 🟡 Baja

### Configuración detectada

```text
priority = 1000
```

en todas las reglas.

### Problema

Todas las reglas utilizan la misma prioridad.

### Riesgo

Aunque la configuración es funcional, dificulta la implementación de reglas más específicas o de políticas de denegación con diferentes niveles de precedencia.

Esto puede generar errores de administración y afectar la mantenibilidad del firewall.

### Recomendación

Definir prioridades según el nivel de criticidad de las reglas.

Ejemplo:

- Prioridades bajas (100–500): reglas críticas.
- Prioridad 1000: reglas generales.
- Prioridades superiores: excepciones específicas.

---

# Resumen de Hallazgos

| Severidad | Hallazgo | Riesgo |
|-----------|----------|--------|
| 🔴 Crítica | SSH abierto a Internet | Acceso remoto no autorizado y fuerza bruta |
| 🔴 Crítica | Redis expuesto públicamente | Acceso a datos y compromiso del servicio |
| 🟢 Informativo | PostgreSQL restringido a red privada | Configuración adecuada, aunque mejorable |
| 🟢 Informativo | HTTPS únicamente desde Load Balancer | Buena práctica de seguridad |
| 🟡 Baja | Prioridades idénticas en todas las reglas | Menor flexibilidad y mantenibilidad |

---

# Conclusión

La revisión de las reglas de firewall evidencia una postura de seguridad mixta. Mientras que las reglas asociadas al acceso HTTPS desde el **Google Cloud Load Balancer** y la restricción del acceso a PostgreSQL siguen buenas prácticas de segmentación, la exposición pública de los servicios **SSH** y **Redis** representa un riesgo crítico para la infraestructura.

Como acciones prioritarias, se recomienda eliminar el acceso público a los puertos **22** y **6379**, restringiendo las conexiones únicamente a redes o identidades autorizadas. Adicionalmente, es aconsejable complementar la protección perimetral con controles como **Identity-Aware Proxy (IAP)** para la administración remota, **Cloud Armor** para la protección de aplicaciones web y una estrategia de segmentación de red basada en el principio de mínimo privilegio.