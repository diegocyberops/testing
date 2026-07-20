# Auditoría de Seguridad – IAM (`iam-policy.json`)

## Resumen

Se realizó una revisión de la política IAM exportada del proyecto **nimbopay-prod**, identificando múltiples configuraciones que incumplen el principio de **Least Privilege (Menor Privilegio)** y representan riesgos significativos para la confidencialidad, integridad y disponibilidad del entorno. Los hallazgos incluyen asignaciones excesivas de privilegios, exposición pública de secretos y una administración insegura de cuentas de servicio.

---

# Hallazgos

## Hallazgo 1 – Uso del rol Owner para un usuario

**Severidad:** 🔴 Crítica

### Recurso

Usuario:

```text
user:diego.rivas@nimbopay.example
```

### Configuración detectada

```json
{
  "role": "roles/owner",
  "members": [
    "user:diego.rivas@nimbopay.example"
  ]
}
```

### Problema

El usuario posee el rol **Owner**, el cual otorga control total sobre el proyecto, incluyendo:

- Administración de IAM.
- Creación y eliminación de recursos.
- Modificación de políticas.
- Gestión de cuentas de servicio.
- Acceso a prácticamente todos los servicios.

### Riesgo

En caso de compromiso de la cuenta del usuario, un atacante podría tomar control completo del proyecto, escalar privilegios, eliminar recursos o extraer información sensible.

### Recomendación

Aplicar el principio de **Least Privilege**, reemplazando el rol **Owner** por una combinación de roles específicos según las funciones reales del usuario.

Ejemplos:

- roles/viewer
- roles/compute.admin
- roles/storage.admin
- roles/logging.viewer

---

# Hallazgo 2 – Cuenta de servicio con rol Owner

**Severidad:** 🔴 Crítica

### Recurso

```text
serviceAccount:deploy-bot@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
{
  "role": "roles/owner"
}
```

### Problema

Una cuenta de servicio utilizada para despliegues automáticos posee privilegios de **Owner**.

### Riesgo

Si la cuenta de servicio es comprometida (por ejemplo mediante una clave filtrada), un atacante obtendría control total sobre toda la infraestructura del proyecto.

Este escenario constituye uno de los vectores más comunes de compromiso en entornos Cloud.

### Recomendación

Asignar únicamente los permisos necesarios para el proceso de despliegue.

Por ejemplo:

- roles/cloudbuild.builds.builder
- roles/run.admin
- roles/storage.admin
- roles/artifactregistry.writer

Evitar completamente el uso de **roles/owner** en cuentas de servicio.

---

# Hallazgo 3 – Uso del rol Editor para cargas de trabajo

**Severidad:** 🟠 Alta

### Recurso

```text
serviceAccount:api-workload@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
{
  "role": "roles/editor"
}
```

### Problema

La cuenta de servicio utilizada por la aplicación posee el rol **Editor**, el cual concede permisos de escritura sobre una gran cantidad de recursos del proyecto.

### Riesgo

Una vulnerabilidad en la aplicación permitiría modificar infraestructura, crear recursos o alterar configuraciones que exceden las necesidades funcionales de la aplicación.

### Recomendación

Crear un rol personalizado o asignar únicamente los permisos estrictamente necesarios.

Ejemplos:

- Cloud SQL Client
- Secret Manager Secret Accessor
- Storage Object Viewer

Evitar el uso de roles básicos como:

- Owner
- Editor
- Viewer

---

# Hallazgo 4 – Grupo operativo con rol Editor

**Severidad:** 🟠 Alta

### Recurso

```text
group:ops-team@nimbopay.example
```

### Configuración detectada

```json
{
  "role": "roles/editor"
}
```

### Problema

Todo el grupo operativo posee privilegios de edición sobre el proyecto.

### Riesgo

Cualquier miembro agregado al grupo heredará automáticamente permisos elevados.

Si una cuenta del grupo es comprometida, el atacante dispondrá de amplias capacidades sobre la infraestructura.

### Recomendación

Asignar roles específicos según responsabilidades.

Ejemplos:

- Logging Viewer
- Monitoring Viewer
- Compute Viewer
- Storage Object Viewer

Aplicar separación de funciones (Separation of Duties).

---

# Hallazgo 5 – Administración de claves de cuentas de servicio

**Severidad:** 🔴 Crítica

### Recurso

```text
serviceAccount:api-workload@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
{
  "role": "roles/iam.serviceAccountKeyAdmin"
}
```

### Problema

La propia cuenta de servicio puede administrar sus propias claves.

### Riesgo

Permite generar nuevas claves JSON permanentes.

Si un atacante compromete la cuenta podrá:

- Crear nuevas credenciales.
- Mantener persistencia.
- Evadir mecanismos de rotación.

### Recomendación

Eliminar este rol.

Utilizar:

- Workload Identity
- Credenciales temporales
- IAM Credentials API

Evitar completamente el uso de claves JSON siempre que sea posible.

---

# Hallazgo 6 – Acceso público a Secret Manager

**Severidad:** 🔴 Crítica

### Recurso

```text
allUsers
```

### Configuración detectada

```json
{
  "role": "roles/secretmanager.secretAccessor",
  "members": [
    "allUsers"
  ]
}
```

### Problema

Todos los usuarios de Internet pueden acceder a los secretos del proyecto.

### Riesgo

Exposición completa de:

- API Keys
- Contraseñas
- Tokens
- Certificados
- Credenciales de bases de datos

Este hallazgo representa una exposición crítica de información sensible.

### Recomendación

Eliminar inmediatamente el miembro:

```text
allUsers
```

Asignar acceso únicamente a:

- cuentas de servicio autorizadas
- grupos específicos
- usuarios autorizados

Aplicar el principio de mínimo privilegio.

---

# Hallazgo 7 – Permiso Cloud SQL correctamente limitado

**Severidad:** 🟢 Informativo

### Recurso

```text
serviceAccount:api-workload@nimbopay-prod.iam.gserviceaccount.com
```

### Configuración detectada

```json
{
  "role": "roles/cloudsql.client"
}
```

### Observación

El permiso Cloud SQL Client corresponde al acceso esperado para una aplicación que necesita conectarse a una instancia de Cloud SQL.

### Riesgo

No representa un riesgo por sí solo.

Sin embargo, combinado con el rol **Editor**, incrementa la superficie de ataque.

### Recomendación

Mantener este rol únicamente si la aplicación realmente requiere conectarse a Cloud SQL.

---

# Resumen de Hallazgos

| Severidad | Hallazgo | Riesgo |
|-----------|----------|--------|
| 🔴 Crítica | Usuario con rol Owner | Control total del proyecto |
| 🔴 Crítica | Cuenta de servicio con rol Owner | Compromiso total mediante credenciales |
| 🟠 Alta | Cuenta de servicio con rol Editor | Exceso de privilegios |
| 🟠 Alta | Grupo con rol Editor | Escalamiento de privilegios |
| 🔴 Crítica | Service Account Key Admin | Persistencia mediante claves |
| 🔴 Crítica | Secret Manager accesible por allUsers | Exposición pública de secretos |
| 🟢 Informativo | Cloud SQL Client | Permiso adecuado si existe necesidad funcional |

---

# Conclusión

La política IAM presenta varias configuraciones de alto impacto que vulneran principios fundamentales de seguridad en Google Cloud, especialmente el **Principio de Menor Privilegio (Least Privilege)**. Destacan como riesgos críticos la asignación del rol **Owner** a usuarios y cuentas de servicio, la capacidad de una cuenta para administrar sus propias claves y la exposición pública de los secretos mediante el acceso otorgado a **allUsers**.

Como acciones prioritarias, se recomienda eliminar inmediatamente los roles excesivos, restringir el acceso a Secret Manager únicamente a identidades autorizadas, sustituir el uso de claves de cuentas de servicio por **Workload Identity** y definir roles personalizados ajustados a las funciones de cada usuario y aplicación. Estas medidas reducirán significativamente la superficie de ataque y alinearán la configuración con las buenas prácticas de seguridad de Google Cloud y el principio de mínimo privilegio.