# Ejercicio F — Respuesta a Incidentes: Posible Fuga de Datos (INC-2026-0714)

## Marco de referencia

La respuesta se estructura siguiendo el **NIST SP 800-61 Rev.2 - Computer Security Incident Handling Guide**, considerando las fases de:

- Preparación (Preparation)
- Detección y análisis (Detection & Analysis)
- Contención, erradicación y recuperación (Containment, Eradication & Recovery)
- Actividades posteriores al incidente (Post-Incident Activity)

---

# 1. Resumen Ejecutivo

A las **03:14 UTC** se abre el incidente **INC-2026-0714** tras múltiples alertas del SIEM relacionadas con un comportamiento anómalo del comercio **mrc_204**.

Los indicadores observados permiten concluir que existe una **alta probabilidad de exfiltración de información de clientes**, utilizando credenciales válidas del comercio comprometido.

Los principales indicadores son:

- Autenticación desde una región (RU) distinta al comportamiento histórico (CL).
- Uso de un User-Agent distinto al SDK oficial.
- Enumeración masiva de información mediante la API.
- Ausencia de bloqueos por Rate Limiting.
- Firma HMAC válida en todas las solicitudes.
- Publicación de una muestra de registros en un sitio público.

Aunque todavía no es posible confirmar el volumen exacto de información comprometida, la evidencia sugiere que el atacante logró acceder a una cantidad significativa de datos antes de finalizar su actividad.

---

# 2. Supuestos del incidente

Debido a que la información disponible es parcial, se consideran los siguientes supuestos:

- La API funcionó correctamente durante todo el incidente.
- No existieron despliegues recientes que expliquen el comportamiento.
- La firma HMAC válida indica que las credenciales del comercio fueron utilizadas legítimamente desde el punto de vista de autenticación.
- No existe evidencia inicial de compromiso de la infraestructura interna de Nimbo Pay.
- La publicación del paste podría corresponder a datos reales o parcialmente modificados.

Estos supuestos deberán validarse durante la investigación forense.

---

# 3. Clasificación del incidente

**Tipo de incidente**

- Data Breach
- Compromiso de credenciales
- Exfiltración de información
- Uso indebido de API

**Severidad**

**Crítica**

Justificación:

- Posible exposición de datos personales.
- Posible compromiso de hasta 120.000 clientes.
- Existencia de evidencia pública del incidente.
- Riesgo reputacional y regulatorio elevado.

---

# 4. Detección y Análisis (Detection & Analysis)

## Línea temporal

| Hora | Evento |
|--------|---------|
|03:02|Inicio de acceso desde RU|
|03:05|20 veces más tráfico de salida|
|03:08|120 requests/minuto|
|03:14|Apertura del incidente|
|03:20|Alerta DLP|
|03:31|Publicación del paste|
|03:40|Cesa la actividad|

---

## Hallazgos relevantes

### Cambio de comportamiento

Históricamente:

- Región CL
- SDK Ruby oficial
- Decenas de consultas por hora

Durante el incidente:

- Región RU
- python-requests
- Más de 120 solicitudes por minuto

Este comportamiento corresponde a un claro indicador de compromiso de credenciales.

---

### Enumeración de datos

Las primeras consultas muestran:

```
search?email=a%
search?email=b%
search?email=c%
```

Posteriormente aparece:

```
' OR 1=1 --
```

Esto demuestra un intento de:

- Enumerar registros.
- Evaluar posibles vulnerabilidades de inyección.
- Determinar el comportamiento del endpoint.

---

### Exfiltración masiva

Posteriormente el atacante realiza:

```
orders?page=1&per=500
...
orders?page=241&per=500
customers?page=1&per=500
```

Esto evidencia una extracción sistemática de información mediante paginación.

---

### Controles que fallaron

Los logs indican:

- Sin errores 401
- Sin errores 403
- Sin respuestas 429

Esto indica que:

- La autenticación fue válida.
- El Rate Limiting nunca actuó.
- No existían controles de comportamiento anómalo efectivos.

---

# 5. Contención (Primeros 30–60 minutos)

Las acciones deben minimizar la fuga preservando evidencia.

## Prioridad 1 – Declarar incidente

- Activar formalmente el CSIRT.
- Asignar Incident Commander.
- Registrar cronología.

---

## Prioridad 2 – Preservación de evidencia

Antes de modificar sistemas:

- Copiar logs del API Gateway.
- Copiar logs del SIEM.
- Exportar eventos del WAF.
- Respaldar logs de autenticación.
- Preservar evidencia mediante hashes.

---

## Prioridad 3 – Revocar credenciales comprometidas

Revocar inmediatamente:

- API Key de mrc_204
- Secret HMAC
- Tokens asociados

Generar nuevas credenciales únicamente después de validar la integración.

---

## Prioridad 4 – Bloqueo temporal

Aplicar reglas en:

- API Gateway
- WAF
- Firewall

Bloqueando:

- IP 203.0.113.77
- Región RU (si el negocio no opera allí)
- User-Agent python-requests

---

## Prioridad 5 – Limitar exposición

Reducir temporalmente:

- Tamaño máximo de página
- Endpoints de exportación
- Endpoint customers

---

## Prioridad 6 – Activar monitoreo reforzado

Incrementar monitoreo para:

- Todos los comercios
- Cambios de geolocalización
- Accesos fuera del patrón histórico

---

# 6. Identificación del origen (Análisis Forense)

## Hipótesis 1 (Alta probabilidad)

Compromiso de API Key y secreto HMAC del comercio.

Indicadores:

- Firma válida.
- No existen errores de autenticación.
- Cambio brusco de geolocalización.
- Cambio de User-Agent.

---

## Hipótesis 2

Compromiso del servidor del comercio.

Validación:

- Revisar infraestructura del comercio.
- Logs internos.
- Accesos administrativos.
- Rotación reciente de claves.

---

## Hipótesis 3

Vulnerabilidad en la API.

El intento:

```
' OR 1=1 --
```

obliga a revisar:

- Sanitización
- ORM
- Consultas SQL
- Logs de base de datos

---

## Determinación del alcance

Para determinar el volumen comprometido se correlacionarán:

- Logs del API Gateway.
- Logs del SIEM.
- Auditoría de Base de Datos.
- Eventos DLP.
- Número de páginas consultadas.
- Bytes transferidos.
- Endpoint customers.

Se calculará:

- Número de clientes consultados.
- Campos expuestos.
- Tiempo de permanencia.
- Volumen exfiltrado.

---

# 7. Escalamiento y Notificación

## Escalamiento inmediato

Primeros 15 minutos:

- CSIRT
- CISO
- Equipo SOC
- Infraestructura
- Desarrollo API

Primeros 30 minutos:

- Dirección TI
- Área Legal
- Riesgos
- Comunicaciones

---

## Notificación al comercio

Contactar inmediatamente a:

**mrc_204**

Solicitando:

- Confirmar compromiso.
- Revisar servidores.
- Rotar credenciales.
- Compartir evidencia.

---

## Reguladores

Al tratarse de una fintech con posible fuga de datos personales deberán evaluarse obligaciones regulatorias aplicables, incluyendo:

- Autoridad de protección de datos personales.
- Organismo regulador financiero correspondiente.
- Clientes afectados.

La notificación deberá realizarse conforme a los plazos establecidos por la normativa vigente y una vez confirmado el alcance del incidente.

---

# 8. Costeo de soluciones

## Costos del incidente

### Directos

- Investigación forense.
- Horas extraordinarias.
- Asesoría legal.
- Notificaciones.
- Gestión de crisis.

---

### Indirectos

- Daño reputacional.
- Pérdida de clientes.
- Sanciones regulatorias.
- Costos judiciales.
- Pérdida de confianza.

---

## Controles preventivos

|Control|Costo|Impacto|
|---------|------|---------|
|Rate Limiting inteligente|Bajo|Muy Alto|
|Detección por comportamiento|Medio|Muy Alto|
|Geoblocking|Bajo|Alto|
|Rotación automática de API Keys|Bajo|Alto|
|MFA para gestión de credenciales|Bajo|Alto|
|Alertas por User-Agent anómalo|Bajo|Medio|
|DLP avanzado|Medio|Muy Alto|
|Análisis UEBA|Alto|Muy Alto|

---

## Priorización

1. Rate Limiting
2. Rotación automática de claves
3. Geoblocking
4. UEBA
5. DLP
6. Detección basada en comportamiento

La inversión preventiva resulta significativamente menor que el costo potencial de una fuga masiva de datos.

---

# 9. Post-Mortem

## Causa raíz probable

La evidencia disponible apunta a un **compromiso de las credenciales del comercio `mrc_204` (API Key y secreto HMAC)**, utilizadas para acceder legítimamente a la API desde una ubicación geográfica inusual. El atacante explotó la ausencia de controles de comportamiento y de limitación de consultas para realizar una extracción masiva de información.

No obstante, también debe investigarse si el intento de **inyección SQL (`' OR 1=1 --`)** corresponde únicamente a una prueba de reconocimiento o si evidencia una vulnerabilidad en la aplicación.

---

## Lecciones aprendidas

- Las credenciales por sí solas no son suficientes como mecanismo de confianza.
- El Rate Limiting debe considerar comportamiento y no solo volumen.
- La geolocalización debe formar parte del proceso de autenticación adaptativa.
- Las alertas deben poder activar respuestas automáticas.

---

## Controles preventivos

### API

- Rate Limiting adaptativo.
- Cuotas por cliente.
- Límites máximos de paginación.
- Tokens de corta duración.
- Rotación automática de claves.

### Seguridad

- MFA para gestión de credenciales.
- UEBA.
- Geofencing.
- Detección de anomalías.
- DLP reforzado.

### Desarrollo

- Revisión de endpoints de búsqueda.
- Validación de entradas.
- Pruebas de seguridad continuas.
- Revisión OWASP API Security Top 10.

### Monitoreo

- Dashboards dedicados para exfiltración.
- Correlación SIEM + DLP.
- Alertas por User-Agent anómalo.
- Alertas por lectura masiva de registros.

---

# 10. Información faltante

Para confirmar el incidente sería necesario recopilar:

- Logs de Base de Datos.
- Logs del WAF.
- Logs del balanceador.
- Auditoría de IAM.
- Información del comercio mrc_204.
- Evidencia del paste completo.
- Captura de memoria (si aplica).
- Logs del sistema operativo.
- Evidencia del servidor comprometido del comercio.

---

# 11. Conclusión

Con la evidencia disponible, el incidente presenta una **alta probabilidad de corresponder a una exfiltración masiva de datos mediante el uso de credenciales válidas comprometidas**. El patrón de acceso desde una región no habitual, el empleo de un cliente distinto al SDK oficial, la enumeración sistemática de registros y la ausencia de controles efectivos de limitación permitieron la extracción sostenida de información durante aproximadamente 38 minutos.

La respuesta inicial debe priorizar la **contención sin destruir evidencia**, mediante la revocación inmediata de las credenciales comprometidas, el bloqueo del origen malicioso y la preservación de los registros para el análisis forense. Posteriormente, la investigación debe determinar el alcance real de la exposición, confirmar si existió una vulnerabilidad adicional en la API y coordinar las notificaciones regulatorias y a los clientes afectados conforme a la legislación aplicable. Finalmente, la organización deberá fortalecer sus controles de autenticación, monitoreo y protección de APIs para reducir significativamente la probabilidad de recurrencia de incidentes similares.