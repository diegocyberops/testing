# Parte 2 – Demostrar fluidez con `gcloud`

## Objetivo

Al no contar con acceso directo al proyecto **nimbopay-prod**, la auditoría se realiza sobre artefactos exportados. Sin embargo, en un escenario real utilizaría la CLI de **Google Cloud (`gcloud`)** para validar la configuración de seguridad, identificar configuraciones riesgosas y recopilar evidencia desde el propio entorno.

---

# 1. Obtener la política IAM del proyecto

Permite visualizar todos los roles y miembros asignados en el proyecto.

```bash
gcloud projects get-iam-policy nimbopay-prod \
    --format=json
```

### Formato tabular

```bash
gcloud projects get-iam-policy nimbopay-prod \
    --flatten="bindings[].members" \
    --format="table(bindings.role, bindings.members)"
```

**Objetivo**

- Detectar usuarios con privilegios elevados.
- Revisar asignaciones de roles básicos (`Owner`, `Editor`, `Viewer`).
- Verificar el cumplimiento del principio de mínimo privilegio.

---

# 2. Buscar miembros con roles peligrosos

Listar únicamente los roles administrativos más sensibles.

```bash
gcloud projects get-iam-policy nimbopay-prod \
    --flatten="bindings[].members" \
    --filter="bindings.role:owner OR bindings.role:editor" \
    --format="table(bindings.role, bindings.members)"
```

**Objetivo**

Identificar rápidamente usuarios, grupos o cuentas de servicio con privilegios excesivos.

---

# 3. Listar todas las cuentas de servicio

```bash
gcloud iam service-accounts list \
    --format="table(email, displayName, disabled)"
```

**Objetivo**

- Inventariar las cuentas de servicio.
- Identificar cuentas deshabilitadas o potencialmente obsoletas.

---

# 4. Revisar las claves de una cuenta de servicio

```bash
gcloud iam service-accounts keys list \
    --iam-account=api-workload@nimbopay-prod.iam.gserviceaccount.com
```

### Con formato personalizado

```bash
gcloud iam service-accounts keys list \
    --iam-account=api-workload@nimbopay-prod.iam.gserviceaccount.com \
    --format="table(name,keyType,validAfterTime,validBeforeTime)"
```

**Objetivo**

- Detectar claves `USER_MANAGED`.
- Identificar claves antiguas o sin expiración.
- Revisar la necesidad de rotación.

---

# 5. Buscar cuentas con claves administradas por el usuario

```bash
gcloud iam service-accounts keys list \
    --iam-account=api-workload@nimbopay-prod.iam.gserviceaccount.com \
    --filter="keyType=USER_MANAGED"
```

**Objetivo**

Encontrar credenciales permanentes que puedan representar un riesgo de seguridad.

---

# 6. Listar todas las reglas de firewall

```bash
gcloud compute firewall-rules list
```

### Mostrar únicamente la información relevante

```bash
gcloud compute firewall-rules list \
    --format="table(
        name,
        direction,
        priority,
        sourceRanges.list(),
        allowed[].map().firewall_rule().list()
    )"
```

**Objetivo**

- Identificar servicios expuestos.
- Revisar prioridades.
- Validar segmentación de red.

---

# 7. Buscar reglas abiertas a Internet

```bash
gcloud compute firewall-rules list \
    --filter="sourceRanges=0.0.0.0/0"
```

**Objetivo**

Detectar servicios accesibles públicamente.

---

# 8. Buscar exposición de SSH

```bash
gcloud compute firewall-rules list \
    --filter="allowed.tcp:22"
```

**Objetivo**

Verificar si existen servidores accesibles mediante SSH desde Internet.

---

# 9. Buscar exposición de Redis

```bash
gcloud compute firewall-rules list \
    --filter="allowed.tcp:6379"
```

**Objetivo**

Detectar servicios Redis potencialmente expuestos.

---

# 10. Consultar los registros de auditoría (Audit Logs)

```bash
gcloud logging read \
'logName="projects/nimbopay-prod/logs/cloudaudit.googleapis.com%2Factivity"' \
--limit=50 \
--format=json
```

**Objetivo**

Revisar eventos administrativos como:

- Cambios en IAM.
- Eliminación de recursos.
- Creación de cuentas.
- Modificación de permisos.

---

# 11. Revisar accesos a Secret Manager

```bash
gcloud logging read \
'resource.type="secret_manager_secret"' \
--limit=50
```

**Objetivo**

Detectar accesos recientes a secretos y posibles usos no autorizados.

---

# 12. Buscar creación de claves de cuentas de servicio

```bash
gcloud logging read \
'protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"' \
--limit=20
```

**Objetivo**

Identificar la generación de nuevas claves JSON, una acción de alto impacto desde el punto de vista de seguridad.

---

# 13. Revisar accesos a Cloud SQL

```bash
gcloud logging read \
'resource.type="cloudsql_database"' \
--limit=50
```

**Objetivo**

Verificar conexiones y actividades relevantes sobre las bases de datos.

---

# 14. Listar los secretos almacenados

```bash
gcloud secrets list
```

**Objetivo**

Comprobar que las credenciales críticas se encuentren gestionadas mediante **Secret Manager** y no embebidas en archivos de configuración.

---

# 15. Consultar los permisos efectivos de una cuenta

```bash
gcloud projects get-iam-policy nimbopay-prod \
    --flatten="bindings[].members" \
    --filter="bindings.members:api-workload@nimbopay-prod.iam.gserviceaccount.com"
```

**Objetivo**

Identificar todos los roles asignados a una cuenta de servicio específica.

---

# 16. Revisar recomendaciones de IAM

```bash
gcloud recommender recommendations list \
    --recommender=google.iam.policy.Recommender \
    --location=global
```

**Objetivo**

Obtener recomendaciones automáticas para eliminar permisos innecesarios y aplicar el principio de mínimo privilegio.

---

# Resumen

| Auditoría | Comando principal | Objetivo |
|------------|-------------------|----------|
| Política IAM | `gcloud projects get-iam-policy` | Revisar roles y miembros |
| Roles peligrosos | `--filter="bindings.role:owner OR bindings.role:editor"` | Detectar privilegios excesivos |
| Cuentas de servicio | `gcloud iam service-accounts list` | Inventario de Service Accounts |
| Claves de Service Accounts | `gcloud iam service-accounts keys list` | Detectar claves permanentes |
| Firewall | `gcloud compute firewall-rules list` | Revisar exposición de red |
| Firewall público | `--filter="sourceRanges=0.0.0.0/0"` | Detectar servicios expuestos |
| Audit Logs | `gcloud logging read` | Revisar eventos administrativos |
| Secret Manager | `gcloud secrets list` | Verificar gestión de secretos |
| Accesos a secretos | `resource.type="secret_manager_secret"` | Auditar uso de credenciales |
| IAM Recommender | `gcloud recommender recommendations list` | Reducir privilegios innecesarios |

---

# Conclusión

En un entorno de producción, la combinación de los comandos anteriores permitiría realizar una auditoría rápida y efectiva de la postura de seguridad del proyecto. Estos comandos facilitan la identificación de configuraciones inseguras en **IAM**, **Service Accounts**, **Firewall**, **Secret Manager** y **Cloud Logging**, proporcionando evidencia suficiente para evaluar el cumplimiento del principio de mínimo privilegio, detectar exposiciones de red y revisar eventos críticos registrados en los **Cloud Audit Logs**. Este enfoque está alineado con las buenas prácticas recomendadas por Google Cloud para la evaluación continua de la seguridad.