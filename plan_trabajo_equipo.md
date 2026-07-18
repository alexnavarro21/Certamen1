# Plan de trabajo en equipo — Certamen 1

Equipo: Alex (Cassandra), César - macOS (MongoDB), Nacha - Windows (DynamoDB)

Repo compartido: `main.tf` único con los tres motores. Deadline: lunes 20 de julio, 23:59.

## Fase 0 — Preparación (los tres, en paralelo)

- Clonar el repo de GitHub y confirmar acceso al `main.tf` compartido.
- Instalar Terraform y AWS CLI en cada equipo: Alex y César vía Homebrew (macOS); Nacha usando WSL o Git Bash en Windows, no PowerShell puro, para que SSH y los permisos del `.pem` se comporten igual que en Mac.
- Cada uno inicia su propia sesión del AWS Academy Learner Lab y copia sus credenciales temporales a su propio `~/.aws/credentials` local.

## Fase 1 — Desarrollo y prueba individual (cada uno en su propia cuenta del Learner Lab)

No se corre el `main.tf` completo individualmente, para no levantar los tres motores en cada cuenta y gastar horas de Lab sin necesidad. Se usa `-target` para aplicar solo la parte de cada uno:

- Alex: `terraform apply -target=aws_security_group.streamvault_sg -target=aws_instance.cassandra`
- César: `terraform apply -target=aws_security_group.streamvault_sg -target=aws_instance.mongodb`
- Nacha: `terraform apply -target=aws_security_group.streamvault_sg -target=aws_dynamodb_table.sesiones_activas -target=aws_dynamodb_table_item.sesion_1 -target=aws_dynamodb_table_item.sesion_2 -target=aws_dynamodb_table_item.sesion_3 -target=aws_dynamodb_table_item.sesion_4 -target=aws_dynamodb_table_item.sesion_5 -target=aws_instance.dynamo_client`

Cada uno se conecta por SSH a su instancia, verifica que el motor esté corriendo, y prueba/ajusta las 3 consultas que le corresponden hasta que funcionen bien.

Si alguien necesita modificar su bloque de `user_data` en el `main.tf` (bug, ajuste de versión, etc.), hace `git pull` antes de editar, y hace commit solo de su sección para minimizar choques, ya que los tres tocan el mismo archivo.

Cuando cada uno valida que su parte funciona, corre `terraform destroy` sobre lo que levantó, para dejar su cuenta limpia y no seguir gastando presupuesto del Lab.

## Fase 2 — Integración: la corrida conjunta (los tres presentes, mismo horario)

Uno del equipo actúa de integrador: quien realmente levanta la infraestructura completa que queda como evidencia final. Conviene que sea Alex o César (macOS), ya que el entorno local de Terraform suele ser más estable ahí.

- Todos hacen `git pull` para tener el `main.tf` con las tres partes ya integradas y probadas.
- Se juntan por videollamada con pantalla compartida.
- El integrador corre `terraform init`, `terraform plan` y `terraform apply` completos (sin `-target`) en su propia cuenta del Learner Lab.
- Se capturan las pantallas de esos tres comandos y de las tres instancias en estado `running` en la consola de AWS (esta evidencia debe salir de una sola ejecución conjunta).

**Sobre credenciales y acceso:** como toda la infraestructura queda en la cuenta del integrador, César y Nacha necesitan la misma llave `.pem` que usó el integrador (normalmente `vockey.pem`) para conectarse por SSH a "sus" instancias. El integrador la comparte por un canal privado, nunca por el repo público. Para DynamoDB en particular, la instancia cliente necesita las credenciales de AWS de la cuenta del integrador (no las de Nacha) configuradas en su `~/.aws/credentials`, porque la tabla vive en esa cuenta. Lo más simple: el integrador configura esas credenciales mientras comparte pantalla, o se las pasa a Nacha en privado para que ella las configure y corra las consultas desde su propia sesión SSH.

## Fase 3 — Cada uno ejecuta y documenta sus propias consultas

Con la infraestructura conjunta arriba, cada uno se conecta por SSH a su instancia (usando la llave compartida) desde su propia máquina:

- Alex corre sus 3 consultas en Cassandra con `cqlsh`.
- César corre sus 3 consultas en MongoDB con `mongosh`.
- Nacha corre el script `consultas_dynamodb.sh` ya preparado en la instancia cliente de DynamoDB.

Cada uno toma sus propias capturas de la conexión SSH, el motor corriendo, y los resultados de sus 3 consultas, para incorporarlas al manual de evidencia compartido.

## Fase 4 — Cierre

Una vez reunidas todas las capturas, el integrador corre `terraform destroy` para liberar toda la infraestructura y no seguir consumiendo el Lab. El equipo revisa junto que el manual de evidencia esté completo y que el `main.tf` en el repo sea la versión final efectivamente usada.

## Fase 5 — Informe individual

Cada integrante arma su propio documento de entrega con: el mismo `main.tf`, el mismo manual de evidencia (con las capturas conjuntas), y sus propias respuestas escritas a las 4 preguntas de análisis, discutidas en conjunto pero redactadas por cada uno con sus propias palabras.

## Cronograma sugerido

- **Viernes / sábado:** Fase 0 y Fase 1 (desarrollo y prueba individual).
- **Domingo:** Fase 2 y Fase 3 (integración conjunta y consultas).
- **Lunes:** Fase 4, Fase 5 y envío con margen antes de las 23:59.
