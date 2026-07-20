# Revisión de Seguridad - nginx.conf

## Resumen Ejecutivo

Se realizó una revisión de la configuración del reverse proxy **Nginx** que expone la API pública de Nimbo Pay. Se identificaron múltiples debilidades que afectan la confidencialidad, integridad y disponibilidad del servicio.

### Resumen de criticidad

| Severidad | Cantidad |
|-----------|----------|
| 🔴 Crítica | 2 |
| 🟠 Alta | 6 |
| 🟡 Media | 4 |
| 🟢 Baja | 1 |

---

# Hallazgos

## 1. Divulgación de versión de Nginx

**Severidad:** 🟡 Media

### Ubicación

```nginx
server_tokens on;
```

### Riesgo

El servidor informa la versión exacta de Nginx en las respuestas HTTP.

Esto facilita el fingerprinting y permite que un atacante identifique vulnerabilidades conocidas asociadas a esa versión.

### Recomendación

Deshabilitar:

```nginx
server_tokens off;
```

---

## 2. Exposición de credenciales en los logs

**Severidad:** 🔴 Crítica

### Ubicación

```nginx
log_format main ...
auth="$http_authorization"
args="$query_string"
```

### Riesgo

Se registran:

- Tokens Bearer
- API Keys
- JWT
- parámetros GET completos

En caso de compromiso del servidor, un atacante obtendría credenciales válidas.

### Recomendación

Eliminar del formato de logs:

- Authorization
- Query String sensible

Registrar únicamente la información necesaria para auditoría.

---

## 3. Uso de protocolos TLS inseguros

**Severidad:** 🔴 Crítica

### Ubicación

```nginx
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
```

### Riesgo

TLS 1.0 y TLS 1.1 están obsoletos y presentan debilidades criptográficas.

No cumplen con recomendaciones modernas de seguridad (PCI DSS, NIST).

### Recomendación

Permitir únicamente:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

---

## 4. Suite criptográfica demasiado permisiva

**Severidad:** 🟠 Alta

### Ubicación

```nginx
ssl_ciphers HIGH:MEDIUM:!aNULL:!MD5;
```

### Riesgo

La política permite algoritmos criptográficos antiguos.

Esto reduce el nivel de seguridad de la conexión TLS.

### Recomendación

Usar únicamente suites modernas compatibles con TLS 1.2 y TLS 1.3.

---

## 5. No se priorizan los cifrados del servidor

**Severidad:** 🟡 Media

### Ubicación

```nginx
ssl_prefer_server_ciphers off;
```

### Riesgo

El cliente puede negociar algoritmos menos seguros.

### Recomendación

```nginx
ssl_prefer_server_ciphers on;
```

---

## 6. Ausencia de cabeceras HTTP de seguridad

**Severidad:** 🟠 Alta

### Riesgo

La aplicación no implementa medidas adicionales contra ataques del navegador.

Faltan:

- HSTS
- X-Frame-Options
- X-Content-Type-Options
- Referrer-Policy
- Content-Security-Policy

### Recomendación

Agregar todas las cabeceras recomendadas.

---

## 7. Uso inseguro de X-Forwarded-For

**Severidad:** 🟠 Alta

### Ubicación

```nginx
proxy_set_header X-Forwarded-For $http_x_forwarded_for;
```

### Riesgo

El servidor confía completamente en el valor enviado por el cliente.

Esto permite falsificar direcciones IP.

Puede afectar:

- auditoría
- rate limiting
- detección de fraude
- listas blancas

### Recomendación

Usar:

```nginx
$proxy_add_x_forwarded_for
```

---

## 8. Endpoints internos expuestos públicamente

**Severidad:** 🟠 Alta

### Ubicación

```nginx
location /internal/
```

### Riesgo

Los endpoints internos quedan accesibles desde Internet.

Pueden revelar:

- métricas
- estado del sistema
- información operacional

### Recomendación

Restringir mediante:

- allow / deny
- ACL
- VPN
- Load Balancer interno

---

## 9. Sin límites para tamaño de peticiones

**Severidad:** 🟠 Alta

### Riesgo

Un atacante puede enviar cuerpos HTTP extremadamente grandes.

Consecuencias:

- consumo excesivo de memoria
- denegación de servicio

### Recomendación

Configurar:

```nginx
client_max_body_size 10M;
```

o el tamaño requerido por la aplicación.

---

## 10. Ausencia de Rate Limiting

**Severidad:** 🟠 Alta

### Riesgo

No existe protección contra:

- fuerza bruta
- scraping
- abuso de APIs
- ataques de denegación de servicio

### Recomendación

Implementar:

```nginx
limit_req_zone
limit_req
```

---

## 11. Sin Proxy Timeouts

**Severidad:** 🟡 Media

### Riesgo

Las conexiones pueden permanecer abiertas indefinidamente.

Favorece ataques Slow HTTP.

### Recomendación

Configurar:

- proxy_connect_timeout
- proxy_read_timeout
- proxy_send_timeout

---

## 12. Dotfiles accesibles

**Severidad:** 🟡 Media

### Riesgo

Archivos ocultos pueden quedar expuestos.

Ejemplos:

```
.git
.env
.htpasswd
```

### Recomendación

Bloquear:

```nginx
location ~ /\. {
    deny all;
}
```

---

## 13. HTTP/2 no habilitado

**Severidad:** 🟢 Baja

### Riesgo

No representa una vulnerabilidad directa, pero reduce el rendimiento.

### Recomendación

```
listen 443 ssl http2;
```

---

# Priorización

| Prioridad | Hallazgo |
|------------|-----------|
| 🔴 | Logs con Authorization |
| 🔴 | TLS 1.0 / TLS 1.1 |
| 🟠 | Endpoints internos públicos |
| 🟠 | Sin Rate Limiting |
| 🟠 | X-Forwarded-For inseguro |
| 🟠 | Sin Security Headers |
| 🟠 | Sin límite de Body |
| 🟠 | Ciphers débiles |
| 🟡 | Proxy Timeouts |
| 🟡 | server_tokens |
| 🟡 | Dotfiles |
| 🟢 | HTTP/2 |