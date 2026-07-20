# Ejercicio A – Revisión de Merge Request

## Comentarios de revisión del MR

### 🔴 [CRÍTICA] SQL Injection en el método `search`

**Archivo:** `app/controllers/api/v1/merchants/orders_controller.rb`

**Problema**

La consulta SQL se construye mediante interpolación directa de un parámetro controlado por el usuario:

```ruby
Order.where("customer_email = '#{params[:email]}'")
```

Esto permite que un atacante inyecte código SQL modificando el parámetro `email`, comprometiendo la confidencialidad e integridad de la base de datos.

**Riesgo**

- SQL Injection (OWASP Top 10 2021 – A03: Injection).
- Exposición masiva de información.
- Posible alteración o eliminación de datos dependiendo de los permisos de la base de datos.

**Recomendación**

Utilizar consultas parametrizadas proporcionadas por ActiveRecord:

```ruby
Order.where(customer_email: params[:email])
```

o

```ruby
Order.where("customer_email = ?", params[:email])
```

---

### 🔴 [CRÍTICA] Mass Assignment en `update_customer`

**Archivo:** `app/controllers/api/v1/merchants/orders_controller.rb`

**Problema**

El controlador actualiza el modelo utilizando directamente los parámetros enviados por el cliente:

```ruby
customer.update(params[:customer])
```

Esto omite el mecanismo de **Strong Parameters** de Rails y permite modificar atributos que no deberían ser editables.

**Riesgo**

- Escalada de privilegios.
- Modificación de atributos sensibles.
- Violación del principio de mínimo privilegio.

**Recomendación**

Implementar Strong Parameters:

```ruby
customer.update(customer_params)
```

y definir:

```ruby
def customer_params
  params.require(:customer).permit(:name, :email, :phone)
end
```

---

### 🔴 [CRÍTICA] Insecure Direct Object Reference (IDOR)

**Archivo:** `app/controllers/api/v1/merchants/orders_controller.rb`

**Problema**

El método `show` obtiene la orden únicamente mediante su identificador:

```ruby
Order.find(params[:id])
```

No existe ninguna validación que garantice que la orden pertenece al comercio autenticado.

**Riesgo**

Un comercio podría acceder a órdenes pertenecientes a otros comercios simplemente modificando el identificador de la URL.

**Recomendación**

Restringir la búsqueda al contexto del comercio autenticado:

```ruby
current_merchant.orders.find(params[:id])
```

---

### 🟠 [ALTA] Exposición de información sensible en logs

**Archivo:** `app/controllers/api/v1/merchants/orders_controller.rb`

**Problema**

El controlador registra información personal identificable (PII):

- Correo electrónico.
- Número de documento.
- Información de la transacción.

```ruby
Rails.logger.info(...)
```

**Riesgo**

Los logs suelen almacenarse en plataformas centralizadas (Cloud Logging, SIEM, Splunk, Elastic, etc.), aumentando el riesgo de exposición de datos personales y posibles incumplimientos regulatorios.

**Recomendación**

Registrar únicamente información técnica necesaria para auditoría, evitando almacenar datos personales o financieros.

---

### 🟡 [MEDIA] Uso directo de parámetros en la creación de órdenes

**Archivo:** `app/controllers/api/v1/merchants/orders_controller.rb`

**Problema**

Los parámetros `amount` y `currency` son utilizados directamente desde la solicitud HTTP.

Aunque no representan una vulnerabilidad inmediata, no siguen las buenas prácticas recomendadas por Rails.

**Recomendación**

Definir un método `order_params` utilizando Strong Parameters para mantener un manejo consistente y seguro de los parámetros recibidos.