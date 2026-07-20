# Explicación del diseño

## Modelo de seguridad (deny-by-default)

La política implementa un enfoque **Zero Trust** basado en el principio de **deny-by-default**, donde únicamente se permite el acceso a los endpoints explícitamente autorizados. Las primeras reglas corresponden a las rutas legítimas de la API (`/status`, `/merchants`, `/orders`, `/hooks`, `/catalog` y `/docs`), mientras que cualquier solicitud que no coincida con ellas será bloqueada mediante una regla explícita `deny(403)` y, como medida adicional, por la regla *default deny*. Este enfoque reduce significativamente la superficie de ataque y aplica el principio de mínimo privilegio.

---

## Prioridades

Las reglas fueron organizadas siguiendo el flujo de evaluación de Cloud Armor, donde los valores de prioridad más bajos se evalúan primero.

| Prioridad | Regla | Justificación |
|-----------|--------|---------------|
|100|Health Check|Permite las verificaciones de disponibilidad del servicio.|
|110|Merchants API|Permite el acceso a la API utilizada por los comercios autorizados.|
|120|Orders API|Habilita las operaciones principales del negocio.|
|130|Incoming Webhooks|Permite la recepción de eventos desde servicios externos confiables.|
|140|Public Catalog|Permite el acceso al catálogo público.|
|150|API Documentation|Permite el acceso a la documentación pública de la API.|
|300|Rate Limiting|Protege el endpoint de autenticación frente a ataques de fuerza bruta.|
|2000|Explicit Deny|Bloquea cualquier ruta que no haya sido autorizada previamente.|
|2147483647|Default Deny|Garantiza que cualquier solicitud restante sea denegada.|

Este orden asegura que el tráfico legítimo sea evaluado antes de aplicar el bloqueo general.

---

## Regla Default

La regla por defecto fue configurada como:

```text
action = "deny(403)"
```

Con esta configuración se garantiza que cualquier solicitud que no coincida con una regla *allow* será rechazada automáticamente. Esto implementa correctamente el modelo **deny-by-default**, evitando que nuevos endpoints queden expuestos accidentalmente si no se agregan explícitamente a la lista de rutas permitidas.

---

## Preview Mode

Para minimizar el riesgo durante la migración desde una política permisiva hacia una política **deny-by-default**, las reglas de tipo **allow** y la regla de **rate limiting** se despliegan inicialmente utilizando:

```text
preview = true
```

En este modo, Cloud Armor registra qué solicitudes habrían coincidido con cada regla sin aplicarlas realmente. Esto permite revisar los registros en **Cloud Logging**, identificar falsos positivos y validar que únicamente el tráfico esperado sería permitido. Una vez finalizada la validación, las reglas se cambian gradualmente a:

```text
preview = false
```

aplicando los cambios de forma controlada y reduciendo el riesgo de afectar usuarios legítimos.

---

## Plan de Rollback

El despliegue se realizaría mediante **Terraform**, manteniendo la política anterior versionada en Git. El proceso sería el siguiente:

1. Desplegar la nueva política utilizando `preview = true`.
2. Monitorear los registros y métricas en Cloud Logging y Cloud Monitoring.
3. Cambiar gradualmente las reglas a modo de ejecución (`preview = false`).
4. Verificar el comportamiento de la aplicación y la ausencia de falsos positivos.
5. Finalmente, activar el modelo completo **deny-by-default**.

Si durante la implementación se detecta un incremento inesperado de respuestas **HTTP 403**, errores de aplicación o bloqueo de usuarios legítimos, el rollback consistirá en:

- Restaurar la versión anterior de la política mediante `terraform apply`.
- Reasociar la política anterior al Backend Service o Load Balancer.
- Analizar los registros para identificar la regla responsable antes de realizar un nuevo despliegue.

Al utilizar Infraestructura como Código (IaC), el proceso de reversión es rápido, reproducible y completamente auditable.

---

## Rate Limiting

El **rate limiting** se aplica únicamente sobre el endpoint de autenticación:

```text
/api/v1/sessions
```

ya que representa uno de los principales objetivos de ataques de fuerza bruta y **credential stuffing**.

La política utiliza la acción:

```text
rate_based_ban
```

con los siguientes parámetros:

- **50 solicitudes por minuto**
- **Bloqueo durante 10 minutos**
- **HTTP 429** cuando se supera el umbral
- **enforce_on_key = "IP"**

Aplicar el límite por dirección IP permite reducir ataques automatizados sin afectar el rendimiento del resto de la API. Dependiendo de la arquitectura, también podría utilizarse `XFF_IP` cuando exista un proxy o balanceador que preserve la IP original del cliente.