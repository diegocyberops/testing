# Auditoría de Seguridad – Configuración de la Aplicación (`app.env.yaml`)

## Resumen

Se revisó el archivo de configuración de despliegue de la aplicación **App Engine Flexible** del proyecto **nimbopay-prod**. El análisis identificó múltiples hallazgos relacionados con la gestión insegura de secretos y credenciales, incluyendo contraseñas, claves API y secretos criptográficos almacenados directamente en el archivo de configuración. Estas prácticas incrementan significativamente el riesgo de exposición de información sensible y contravienen las recomendaciones de seguridad de Google Cloud.

---

# Hallazgos

## Hallazgo 1 – Credenciales de base de datos almacenadas en texto plano

**Severidad:** 🔴 Crítica

### Recurso

```yaml
DATABASE_URL
```

### Configuración detectada

```yaml
DATABASE_URL: "postgres://app_user:Pg-Pr0d-2024-xyz@172.16.4.20:5432/nimbopay"
```

### Problema

La cadena de conexión contiene el nombre de usuario y la contraseña de la base de datos almacenados directamente en el archivo de configuración.

### Riesgo

Si el archivo es expuesto mediante:

- un repositorio Git,
- un backup,
- una mala configuración de permisos,
- o un incidente de seguridad,

un atacante obtendría acceso directo a la base de datos de producción.

### Recomendación

- Almacenar la contraseña en **Google Secret Manager**.
- Recuperar el secreto durante la ejecución de la aplicación.
- Evitar almacenar credenciales dentro de archivos de configuración o variables de entorno persistentes.

---

# Hallazgo 2 – API Key expuesta

**Severidad:** 🔴 Crítica

### Recurso

```yaml
DELIVERY_API_KEY
```

### Configuración detectada

```yaml
DELIVERY_API_KEY: "key-2a7c9f1b4d3e6081ca52bf94e0d7136a"
```

### Problema

La clave de acceso a un servicio externo se encuentra almacenada en texto plano.

### Riesgo

Una API Key comprometida puede permitir:

- Consumo no autorizado del servicio.
- Robo de información.
- Generación de costos adicionales.
- Suplantación de la aplicación frente al proveedor externo.

### Recomendación

- Migrar la clave a **Google Secret Manager**.
- Implementar rotación periódica de credenciales.
- Limitar el alcance de la API Key mediante restricciones de uso cuando el proveedor lo permita.

---

# Hallazgo 3 – Secreto criptográfico almacenado en texto plano

**Severidad:** 🔴 Crítica

### Recurso

```yaml
SESSION_HMAC_SECRET
```

### Configuración detectada

```yaml
SESSION_HMAC_SECRET: "hardcoded-session-secret-change-me"
```

### Problema

El secreto utilizado para la firma criptográfica de sesiones está codificado directamente en el archivo.

### Riesgo

Si un atacante obtiene este secreto podría:

- Generar cookies de sesión válidas.
- Suplantar usuarios autenticados.
- Modificar información firmada por la aplicación.
- Comprometer la autenticidad e integridad de las sesiones.

### Recomendación

- Almacenar el secreto en **Google Secret Manager**.
- Generar un valor aleatorio con alta entropía.
- Implementar un procedimiento seguro de rotación de secretos.

---

# Hallazgo 4 – Uso de Redis sin autenticación visible

**Severidad:** 🟠 Alta

### Recurso

```yaml
REDIS_URL
```

### Configuración detectada

```yaml
REDIS_URL: "redis://172.16.4.40:6379/0"
```

### Problema

La cadena de conexión no evidencia el uso de autenticación para acceder al servidor Redis.

### Riesgo

Si el servicio Redis estuviera accesible desde otros segmentos de red o debido a una configuración incorrecta del firewall, un atacante podría conectarse sin necesidad de credenciales.

### Recomendación

- Habilitar autenticación para Redis cuando sea compatible con la arquitectura.
- Restringir el acceso únicamente a las aplicaciones autorizadas.
- Mantener el servicio en una red privada sin exposición a Internet.

---

# Hallazgo 5 – Comentario evidencia deuda técnica de seguridad

**Severidad:** 🟡 Media

### Configuración detectada

```yaml
# NOTA: pendiente mover credenciales a Secret Manager
```

### Problema

El propio archivo indica que el equipo conoce la necesidad de migrar las credenciales a un gestor de secretos, pero aún no ha implementado la medida.

### Riesgo

La permanencia de credenciales en archivos de configuración aumenta la probabilidad de filtración accidental y dificulta la gestión segura de secretos.

### Recomendación

Priorizar la migración de todas las credenciales y secretos a **Google Secret Manager**, integrando el acceso mediante las cuentas de servicio autorizadas y eliminando los valores sensibles del código y de los archivos de configuración.

---

# Hallazgo 6 – Configuración de escalamiento automático

**Severidad:** 🟢 Informativo

### Configuración detectada

```yaml
automatic_scaling:
  min_num_instances: 2
  max_num_instances: 20
```

### Observación

La aplicación posee una política de escalamiento automático con un número mínimo y máximo de instancias definido.

### Riesgo

No se identifican riesgos de seguridad asociados a esta configuración.

### Recomendación

Mantener una revisión periódica de los límites de escalamiento para asegurar un equilibrio entre disponibilidad, rendimiento y costos operacionales.

---

# Resumen de Hallazgos

| Severidad | Hallazgo | Riesgo |
|-----------|----------|--------|
| 🔴 Crítica | Credenciales de PostgreSQL en texto plano | Acceso directo a la base de datos |
| 🔴 Crítica | API Key almacenada en el archivo | Uso indebido del servicio externo |
| 🔴 Crítica | Secreto HMAC codificado | Compromiso de sesiones y autenticación |
| 🟠 Alta | Redis sin autenticación visible | Acceso no autorizado al servicio de caché |
| 🟡 Media | Credenciales pendientes de migración | Exposición prolongada de secretos |
| 🟢 Informativo | Escalamiento automático configurado | Configuración adecuada |

---

# Conclusión

La principal debilidad identificada corresponde al manejo inseguro de secretos y credenciales. El archivo contiene información altamente sensible, incluyendo la contraseña de la base de datos, una clave de API y un secreto criptográfico, todos almacenados en texto plano. Esta práctica incumple las recomendaciones de Google Cloud y aumenta considerablemente el riesgo de filtración de información crítica.

Como medida prioritaria, se recomienda migrar todas las credenciales a **Google Secret Manager**, eliminarlas por completo del archivo de configuración y permitir que la aplicación las obtenga dinámicamente mediante una cuenta de servicio con permisos mínimos (`roles/secretmanager.secretAccessor`). Adicionalmente, es aconsejable implementar políticas de rotación periódica de secretos, utilizar valores criptográficamente seguros para los secretos de sesión y revisar la configuración de Redis para asegurar que el servicio requiera autenticación y permanezca accesible únicamente desde la red interna.