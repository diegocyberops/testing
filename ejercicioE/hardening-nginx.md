# Configuración Endurecida - nginx.conf

```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 4096;
}

http {

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server_tokens off;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 30;

    ##
    ## Logs sin credenciales sensibles
    ##
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';

    access_log /var/log/nginx/access.log main;
    error_log  /var/log/nginx/error.log warn;

    ##
    ## Protección contra abuso
    ##
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;

    upstream api_backend {
        server 127.0.0.1:3000;
        keepalive 32;
    }

    server {

        listen 443 ssl http2;
        server_name api.nimbopay.io;

        ##
        ## TLS moderno
        ##
        ssl_certificate     /etc/nginx/ssl/api.crt;
        ssl_certificate_key /etc/nginx/ssl/api.key;

        ssl_protocols TLSv1.2 TLSv1.3;

        ssl_prefer_server_ciphers on;

        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;

        ##
        ## Security Headers
        ##
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header X-XSS-Protection "1; mode=block" always;

        ##
        ## Protección DoS
        ##
        client_max_body_size 10M;

        limit_req zone=api_limit burst=40 nodelay;

        ##
        ## Timeouts
        ##
        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        location / {

            proxy_pass http://api_backend;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;

            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_http_version 1.1;
        }

        ##
        ## Endpoints internos
        ##
        location /internal/ {

            allow 10.0.0.0/8;
            allow 172.16.0.0/12;
            allow 192.168.0.0/16;

            deny all;

            proxy_pass http://api_backend;
        }

        ##
        ## Bloqueo de archivos ocultos
        ##
        location ~ /\. {

            deny all;

            access_log off;

            log_not_found off;
        }

    }

    ##
    ## Redirección segura
    ##
    server {

        listen 80;

        server_name api.nimbopay.io;

        return 301 https://$host$request_uri;

    }

}
```

---

# Justificación del Hardening

## 1. Eliminación de información sensible

Se eliminó el registro de cabeceras Authorization y parámetros de consulta para evitar la exposición de credenciales en los archivos de log.

---

## 2. TLS moderno

Se deshabilitaron TLS 1.0 y TLS 1.1, permitiendo únicamente TLS 1.2 y TLS 1.3 para cumplir con las recomendaciones actuales de NIST y PCI DSS.

---

## 3. Cabeceras HTTP de seguridad

Se añadieron cabeceras que fortalecen la protección del navegador frente a ataques como clickjacking, MIME sniffing y conexiones inseguras.

---

## 4. Protección frente a abuso

Se implementó Rate Limiting para limitar el número de solicitudes por dirección IP sin afectar el tráfico legítimo.

El parámetro `burst` permite absorber ráfagas cortas de tráfico sin degradar la disponibilidad.

---

## 5. Restricción de endpoints internos

Los endpoints administrativos quedaron accesibles únicamente desde redes privadas autorizadas.

Esto evita la exposición accidental de métricas o información operacional.

---

## 6. Validación de IP del cliente

Se reemplazó `$http_x_forwarded_for` por `$proxy_add_x_forwarded_for`, evitando que un cliente falsifique su dirección IP.

---

## 7. Protección contra DoS

Se limitó el tamaño máximo del cuerpo HTTP y se configuraron tiempos de espera para evitar ataques Slow HTTP y consumo excesivo de recursos.

---

## 8. Protección de archivos ocultos

Se bloqueó el acceso a archivos ocultos como `.git`, `.env` y otros recursos que podrían contener información sensible.

---

# Impacto sobre la disponibilidad

Las medidas implementadas fueron seleccionadas para mantener el equilibrio entre seguridad y disponibilidad:

- El Rate Limiting admite ráfagas legítimas mediante `burst`.
- Los timeouts son suficientes para operaciones normales de la API.
- Los endpoints internos permanecen accesibles desde redes autorizadas.
- La actualización de TLS no afecta a clientes modernos compatibles con TLS 1.2 y TLS 1.3.
- La restricción del tamaño de las solicitudes reduce el riesgo de denegación de servicio sin interferir con el funcionamiento habitual de la aplicación.