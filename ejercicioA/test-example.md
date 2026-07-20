# Test de regresión (RSpec)

## Objetivo

Se incorporó un test de regresión para validar que la vulnerabilidad de **SQL Injection** presente en el método `search` no pueda reproducirse nuevamente.

## Escenario evaluado

El test envía como parámetro un valor diseñado para intentar modificar la consulta SQL:

```text
test@test.com' OR 1=1 --
```

Con la implementación vulnerable, este valor era concatenado directamente dentro de la consulta SQL, permitiendo recuperar registros que no correspondían al correo solicitado.

Después de la corrección, ActiveRecord utiliza consultas parametrizadas, por lo que el valor es tratado únicamente como una cadena de texto y no como parte de la sentencia SQL.

## Resultado esperado

El test verifica que:

- El parámetro sea tratado como un dato y no como código SQL.
- No se produzca la ejecución de una inyección SQL.
- Únicamente se recuperen registros asociados al correo electrónico solicitado.

## Cobertura del test

El test garantiza que futuras modificaciones del controlador no reintroduzcan el uso de consultas SQL construidas mediante interpolación de parámetros, evitando la reaparición de esta vulnerabilidad.