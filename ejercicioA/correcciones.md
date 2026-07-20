# Correcciones implementadas

## Branch

```text
feature/security-fixes-orders-api
```

> En caso de entregar un patch, reemplazar por el nombre del archivo `.diff` correspondiente.

## Cambios realizados

### 1. Corrección de SQL Injection

Se reemplazó la consulta vulnerable basada en interpolación de cadenas por una consulta parametrizada utilizando ActiveRecord.

**Antes**

```ruby
Order.where("customer_email = '#{params[:email]}'")
```

**Después**

```ruby
Order.where(customer_email: params[:email])
```

Esta modificación elimina la posibilidad de ejecutar inyecciones SQL mediante el parámetro `email`.

---

### 2. Implementación de Strong Parameters

Se eliminó la actualización directa del modelo utilizando parámetros no filtrados.

**Antes**

```ruby
customer.update(params[:customer])
```

**Después**

```ruby
customer.update(customer_params)
```

Se agregó el método privado:

```ruby
def customer_params
  params.require(:customer).permit(
    :name,
    :email,
    :phone
  )
end
```

Con ello se evita la modificación de atributos sensibles.

---

### 3. Mitigación de IDOR

El acceso a las órdenes fue restringido al contexto del comercio autenticado.

**Antes**

```ruby
Order.find(params[:id])
```

**Después**

```ruby
current_merchant.orders.find(params[:id])
```

Esta modificación impide que un comercio pueda acceder a órdenes pertenecientes a otro comercio manipulando el identificador de la URL.

---

### 4. Eliminación de información sensible en logs

Se eliminó el registro de datos personales identificables (correo electrónico y número de documento) del cliente.

Los logs fueron limitados a información técnica necesaria para auditoría y trazabilidad, reduciendo la exposición de información sensible.

---

### 5. Uso de Strong Parameters para la creación de órdenes

Se incorporó un método `order_params` para encapsular los parámetros permitidos durante la creación de una orden.

Esta modificación mejora la consistencia del controlador y reduce el riesgo asociado al uso directo de parámetros provenientes de la solicitud HTTP.

---

## Impacto

Las correcciones implementadas eliminan vulnerabilidades asociadas a:

- OWASP Top 10 – Broken Access Control.
- OWASP Top 10 – Injection.
- OWASP Top 10 – Insecure Design (Mass Assignment).
- OWASP Top 10 – Security Logging and Monitoring Failures.

Las modificaciones utilizan mecanismos nativos de Ruby on Rails, por lo que mantienen la compatibilidad funcional del feature sin alterar el comportamiento esperado de la API.