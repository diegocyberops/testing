# Auditoría de Seguridad – Service Accounts (`service-accounts.json`)

## Resumen

Se realizó una revisión de las cuentas de servicio configuradas en el proyecto **nimbopay-prod**, identificando debilidades relacionadas con la gestión de credenciales, el uso de claves administradas por usuarios y la ausencia de controles de rotación. Aunque no se detectaron cuentas deshabilitadas o sin propósito aparente, existen riesgos importantes asociados al uso prolongado de claves JSON permanentes.

---

# Hallazgos

## Hallazgo 1 – Uso de múltiples claves administradas por el usuario

**Severidad:** 🔴 Crítica

### Recurso

```text
api-workload@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
"keys": [
  {
    "keyType": "USER_MANAGED",
    "validAfterTime": "2023-02-20T00:00:00Z",
    "validBeforeTime": "9999-12-31T23:59:59Z"
  },
  {
    "keyType": "USER_MANAGED",
    "validAfterTime": "2024-08-11T00:00:00Z",
    "validBeforeTime": "9999-12-31T23:59:59Z"
  }
]
```

### Problema

La cuenta de servicio mantiene **dos claves USER_MANAGED activas simultáneamente**, ambas con fecha de expiración prácticamente indefinida.

### Riesgo

Las claves administradas por el usuario son credenciales estáticas que pueden:

- Filtrarse accidentalmente en repositorios Git.
- Ser copiadas por un atacante.
- Permanecer válidas durante años.
- Utilizarse fuera del entorno de Google Cloud.

La existencia de múltiples claves incrementa la superficie de ataque y dificulta la gestión segura de credenciales.

### Recomendación

- Eliminar las claves que ya no estén en uso.
- Mantener una única credencial activa únicamente cuando sea estrictamente necesario.
- Sustituir las claves JSON por **Workload Identity**, **IAM Credentials API** o credenciales temporales administradas por Google Cloud.

---

# Hallazgo 2 – Claves permanentes sin política de expiración

**Severidad:** 🔴 Crítica

### Recursos

```text
api-workload@nimbopay-prod.iam.gserviceaccount.com

deploy-bot@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

Todas las claves presentan:

```text
validBeforeTime = 9999-12-31T23:59:59Z
```

### Problema

Las claves nunca expiran automáticamente.

### Riesgo

Si una clave es comprometida, podrá seguir utilizándose indefinidamente hasta que sea revocada manualmente.

Esto favorece:

- Persistencia del atacante.
- Robo prolongado de credenciales.
- Acceso no autorizado a recursos del proyecto.

### Recomendación

Implementar una política de:

- Rotación periódica de claves.
- Eliminación automática de claves antiguas.
- Uso preferente de credenciales temporales administradas por Google Cloud.

---

# Hallazgo 3 – Clave antigua en la cuenta de despliegue

**Severidad:** 🟠 Alta

### Recurso

```text
deploy-bot@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
{
  "validAfterTime": "2022-05-03T00:00:00Z"
}
```

### Problema

La clave fue creada hace varios años y continúa activa.

### Riesgo

Las claves antiguas suelen:

- Permanecer olvidadas.
- Estar almacenadas en servidores CI/CD.
- Haber sido copiadas múltiples veces.
- Incrementar el riesgo de filtración.

### Recomendación

- Revocar inmediatamente la clave antigua.
- Generar una nueva únicamente si resulta imprescindible.
- Configurar procesos automáticos de rotación.

---

# Hallazgo 4 – Uso de claves USER_MANAGED en procesos CI/CD

**Severidad:** 🟠 Alta

### Recurso

```text
deploy-bot@nimbopay-prod.iam.gserviceaccount.com
```

### Problema

El proceso de despliegue utiliza una clave administrada manualmente.

### Riesgo

Los pipelines CI/CD representan uno de los objetivos más frecuentes de los atacantes.

Una filtración de la clave permitiría:

- Ejecutar despliegues maliciosos.
- Modificar infraestructura.
- Comprometer la cadena de suministro (Supply Chain Attack).

### Recomendación

Migrar el pipeline a mecanismos de autenticación sin claves, como:

- Workload Identity Federation.
- Cloud Build Service Account.
- IAM Credentials API.
- Autenticación federada con GitHub Actions o GitLab CI.

---

# Hallazgo 5 – Cuenta de solo lectura sin claves

**Severidad:** 🟢 Informativo

### Recurso

```text
analytics-ro@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
"keys": []
```

### Observación

La cuenta de servicio no posee claves administradas por el usuario.

### Riesgo

No se identifican riesgos relacionados con credenciales persistentes.

### Recomendación

Mantener este modelo de autenticación y evitar la creación de claves JSON innecesarias.

---

# Hallazgo 6 – Todas las cuentas de servicio se encuentran habilitadas

**Severidad:** 🟡 Baja

### Configuración detectada

```json
"disabled": false
```

para las tres cuentas de servicio.

### Observación

No existe evidencia de que alguna cuenta esté obsoleta o sin uso; sin embargo, todas permanecen habilitadas.

### Riesgo

Las cuentas de servicio que dejan de utilizarse pueden convertirse en un vector de ataque si conservan permisos activos.

### Recomendación

Realizar revisiones periódicas para:

- Identificar cuentas inactivas.
- Deshabilitar aquellas que ya no sean necesarias.
- Eliminar cuentas de servicio obsoletas.

---

# Resumen de Hallazgos

| Severidad | Hallazgo | Riesgo |
|-----------|----------|--------|
| 🔴 Crítica | Dos claves USER_MANAGED activas | Mayor superficie de ataque |
| 🔴 Crítica | Claves sin expiración | Persistencia indefinida de credenciales |
| 🟠 Alta | Clave antigua en Deploy Bot | Mayor probabilidad de filtración |
| 🟠 Alta | Uso de claves JSON en CI/CD | Riesgo de compromiso de la cadena de suministro |
| 🟢 Informativo | Cuenta sin claves | Configuración recomendada |
| 🟡 Baja | Todas las cuentas habilitadas | Revisar periódicamente su necesidad |

---

# Conclusión

La principal debilidad identificada en las cuentas de servicio corresponde al uso de **claves administradas por el usuario (USER_MANAGED)** con vigencia indefinida. Este enfoque incrementa significativamente el riesgo de exposición de credenciales y facilita la persistencia de un atacante en caso de compromiso.

Como medida prioritaria, se recomienda eliminar progresivamente las claves JSON permanentes y adoptar mecanismos de autenticación modernos como **Workload Identity**, **Workload Identity Federation** o la **IAM Credentials API**, complementando estas acciones con políticas de rotación periódica, monitoreo del uso de credenciales y revisiones continuas de las cuentas de servicio para garantizar el cumplimiento del principio de mínimo privilegio.