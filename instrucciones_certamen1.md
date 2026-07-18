# Certamen 1 — Advanced Databases Workshop

## Instrucciones generales del certamen

Esta actividad es de carácter grupal. Los grupos deben estar conformados por mínimo 2 y máximo 3 personas. No se aceptan trabajos individuales ni grupos de más de 3 integrantes.

El plazo de entrega es hasta el **lunes 20 de julio (23:59)** desde la fecha de publicación de esta actividad. Todos los entregables deben ser enviados antes de la fecha y hora límite; enviar fuera de plazo no se considera el trabajo y queda con nota mínima.

Cada integrante del grupo debe enviar su informe correspondiente.

Cada integrante del grupo debe haber participado activamente en el desarrollo. El manual de evidencia debe reflejar el trabajo real del equipo; se espera que las capturas de pantalla muestren el entorno de trabajo utilizado por el grupo, no capturas descargadas de internet o generadas por inteligencia artificial.

Cualquier indicio de copia entre grupos resultará en la anulación inmediata de la actividad para todos los involucrados.

El uso de inteligencia artificial para redactar el informe o las respuestas de análisis, así como cualquier detección de plagio entre grupos o de fuentes externas, resultará automáticamente en la nota mínima para todos los integrantes del grupo, sin posibilidad de apelación.

## Objetivos

1. Provisionar infraestructura en AWS usando Terraform como herramienta de IaC.
2. Desplegar tres instancias EC2: una con Apache Cassandra, una con MongoDB y una configurada para operar con DynamoDB.
3. Automatizar la instalación, configuración y carga de datos de los tres motores.
4. Verificar el funcionamiento de cada motor ejecutando consultas sobre datos precargados.
5. Distinguir en la práctica los tres modelos de datos: Wide-Column, Documental y Clave-Valor.

## Contexto

StreamVault es una plataforma de streaming de películas en crecimiento con presencia en varios países de Latinoamérica. Su equipo de arquitectura ha decidido migrar su infraestructura de datos a un entorno cloud usando tres motores NoSQL, cada uno asignado según sus fortalezas:

- **Apache Cassandra** para gestionar el historial de reproducciones y eventos de usuario en tiempo real, dado su alto rendimiento de escritura y disponibilidad continua.
- **MongoDB** para gestionar el catálogo de películas, perfiles de usuarios y listas de favoritos, aprovechando su flexibilidad de esquema documental.
- **DynamoDB** como servicio gestionado de AWS para gestionar las sesiones activas de usuarios en tiempo real, sin necesidad de administrar infraestructura propia.

Tu misión es aprovisionar esta infraestructura completa desde cero usando un único archivo `main.tf` de Terraform, de modo que los tres motores queden operativos con sus bases de datos, tablas, colecciones y datos de ejemplo ya cargados y listos para consultar.

### Observaciones

A diferencia de Cassandra y MongoDB, DynamoDB es un servicio gestionado por AWS — no se instala en la instancia. La instancia EC2 actúa como cliente que se comunica con DynamoDB a través de AWS CLI. Por eso:

- Las credenciales del Learner Lab deben estar configuradas en la instancia (`~/.aws/credentials`).

## Entregables

1. Archivo `main.tf` funcional y ejecutable con los tres motores.
2. Manual de evidencia con capturas de pantalla que demuestren:
   - `terraform init`, `plan` y `apply` ejecutados correctamente.
   - Las tres instancias EC2 en estado `running` en la consola de AWS.
   - Conexión SSH a cada instancia y el motor corriendo.
   - Las 3 consultas ejecutadas en Cassandra con sus resultados.
   - Las 3 consultas ejecutadas en MongoDB con sus resultados.
   - Las 3 consultas ejecutadas en DynamoDB con sus resultados.
   - Las tablas de DynamoDB visibles en la consola de AWS.
3. Respuestas a las 4 preguntas de análisis.

## Preguntas

### Pregunta 1 — Arquitectura de datos y decisiones de modelado

StreamVault almacena el historial de reproducciones en Cassandra, el catálogo en MongoDB y las sesiones activas en DynamoDB. Explica por qué cada dato fue asignado al motor que le corresponde. Para cada decisión menciona al menos dos características técnicas del motor que la justifican. Finalmente, ¿qué pasaría a nivel de rendimiento y consistencia si se intentara consolidar todo en un solo motor? Argumenta con lo visto en clases.

### Pregunta 2 — IaC, idempotencia y riesgos en producción

El `user_data` de Terraform se ejecuta una única vez al lanzar la instancia y no vuelve a correr si haces `terraform apply` nuevamente sobre la misma instancia. Explica qué implicancia tiene esto en un entorno de producción real. ¿Qué herramienta de IaC vista en clases complementaría a Terraform para garantizar que la configuración interna de los servidores se mantenga en el estado deseado de forma continua? ¿Por qué no bastaría con solo Terraform?

### Pregunta 3 — Consistencia, disponibilidad y el Teorema CAP

Los tres motores usados en esta actividad tienen posiciones distintas frente al Teorema CAP. Clasifica a Cassandra, MongoDB y DynamoDB según el Teorema CAP (CA, CP o AP) y justifica cada clasificación. Luego, si StreamVault sufriera una partición de red entre dos datacenters, ¿cuál de los tres motores seguiría respondiendo a los usuarios sin interrupciones y cuál detendría las operaciones? ¿Cuál sería el impacto para el negocio en cada caso?

### Pregunta 4 — Escalabilidad y costos en la nube

En esta actividad usaste instancias `t3.medium` para Cassandra y MongoDB, pero DynamoDB no requirió instancia propia de ese tamaño. Explica la diferencia de modelo de costos entre un motor autogestionado como Cassandra y un servicio gestionado como DynamoDB. ¿En qué escenario de uso le conviene a StreamVault pagar por instancias EC2 propias en lugar de usar DynamoDB? ¿Y cuándo sería al revés? Considera volumen de datos, tráfico y equipo técnico disponible.
