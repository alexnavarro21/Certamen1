# Plan de trabajo en equipo — Certamen 1

Equipo: Alex (Cassandra, integrador), César - macOS (MongoDB), Nacha - Windows (DynamoDB)

Repo compartido: `main.tf` único con los tres motores. Deadline: lunes 20 de julio, 23:59.

**Hoy domingo:** solo la parte técnica necesaria para sacar los screenshots del manual de evidencia.
**Mañana lunes:** informe escrito y respuestas a las 4 preguntas de análisis.

## Fase 0 — Preparación (los tres, en paralelo)

- Clonar el repo de GitHub y confirmar acceso al `main.tf` compartido.
- Instalar Terraform y AWS CLI en cada equipo: Alex y César vía Homebrew (macOS); Nacha usando WSL o Git Bash en Windows, no PowerShell puro, para que SSH y los permisos del `.pem` se comporten igual que en Mac.
- Cada uno inicia su propia sesión del AWS Academy Learner Lab y copia sus credenciales temporales a su propio `~/.aws/credentials` local.
- Cada uno corre `terraform init` en su copia local del repo (descarga el provider `hashicorp/aws`; sin esto ningún `apply` de la Fase 1 va a funcionar).

## Fase 1 — Chequeo rápido individual (cada uno en su propia cuenta del Learner Lab, versión acotada por tiempo)

Con el tiempo ajustado de hoy, se salta la prueba individual completa (afinar las 3 consultas de cada uno) y se hace solo un chequeo rápido en paralelo, para confirmar que cada motor instala y levanta bien antes de la corrida conjunta. Esto es clave porque ninguno de los tres scripts de `user_data` se ha probado todavía contra AWS real, y si falla la instalación, `terraform apply` no lo va a mostrar como error: la instancia igual queda `running` aunque el motor no haya quedado bien instalado. Detectar eso ahora, en paralelo y por separado, es mucho más rápido que descubrirlo recién en la corrida conjunta con los tres mirando.

Se usa `-target` para aplicar solo la parte de cada uno:

- Alex: `terraform apply -target=aws_security_group.streamvault_sg -target=aws_instance.cassandra`
- César: `terraform apply -target=aws_security_group.streamvault_sg -target=aws_instance.mongodb`
- Nacha: `terraform apply -target=aws_security_group.streamvault_sg -target=aws_dynamodb_table.sesiones_activas -target=aws_dynamodb_table_item.sesion_1 -target=aws_dynamodb_table_item.sesion_2 -target=aws_dynamodb_table_item.sesion_3 -target=aws_dynamodb_table_item.sesion_4 -target=aws_dynamodb_table_item.sesion_5 -target=aws_instance.dynamo_client`

Cada uno se conecta por SSH y solo confirma que el servicio esté activo (`systemctl status cassandra` / `systemctl status mongod` / `aws sts get-caller-identity`) y que los datos de ejemplo se cargaron. No es necesario afinar ni ensayar las 3 consultas todavía, eso se hace directo en la Fase 3 sobre la infraestructura conjunta.

Si algo falla, se corrige el bloque de `user_data` correspondiente en el `main.tf` (haciendo `git pull` antes de editar y commit solo de la sección propia), y se reintenta el `-target` hasta que el servicio quede activo.

Cuando cada uno confirma que su parte instala bien, corre `terraform destroy` sobre lo que levantó, para dejar su cuenta limpia antes de la corrida conjunta.

## Fase 2 — Integración: la corrida conjunta (los tres presentes, mismo horario)

**Alex es el integrador:** es quien corre el `terraform apply` conjunto en su propia cuenta del Learner Lab, y toda la infraestructura final queda ahí.

- Todos hacen `git pull` para tener el `main.tf` con las tres partes ya integradas y probadas.
- Se juntan por videollamada con pantalla compartida.
- Alex corre `terraform init`, `terraform plan` y `terraform apply` completos (sin `-target`).
- Se capturan las pantallas de esos tres comandos y de las tres instancias en estado `running` en la consola de AWS (esta evidencia debe salir de esta única ejecución conjunta).

**Sobre credenciales y acceso:** como toda la infraestructura queda en la cuenta de Alex, César y Nacha necesitan la misma llave `.pem` que usa Alex (normalmente `vockey.pem`) para conectarse por SSH a "sus" instancias. Alex la comparte por un canal privado, nunca por el repo público. Para DynamoDB en particular, la instancia cliente necesita las credenciales de AWS de la cuenta de Alex (no las de Nacha) configuradas en su `~/.aws/credentials`, porque la tabla vive en esa cuenta. Alex se las pasa a Nacha en privado para que ella misma las configure y corra las consultas desde su propia sesión SSH.

## Fase 3 — Cada uno ejecuta y documenta sus propias consultas

Con la infraestructura conjunta arriba, cada uno se conecta por SSH a su instancia (usando la llave compartida) desde su propia máquina:

- Alex corre sus 3 consultas en Cassandra con `cqlsh`.
- César corre sus 3 consultas en MongoDB con `mongosh`.
- Nacha corre el script `consultas_dynamodb.sh` ya preparado en la instancia cliente de DynamoDB.

Cada uno toma sus propias capturas de la conexión SSH, el motor corriendo, y los resultados de sus 3 consultas.

## Fase 4 — Cierre técnico (hoy)

Una vez reunidas todas las capturas, Alex corre `terraform destroy` para liberar toda la infraestructura y no seguir consumiendo el Lab. El equipo revisa junto que todas las capturas del manual estén completas antes de cerrar la sesión de hoy.

## Capturas de pantalla necesarias (quién la saca)

Los tres deben evidenciar trabajo propio, aunque toda la infraestructura viva en la cuenta de Alex. Las capturas de Terraform y de la consola de AWS las saca Alex por ser quien tiene acceso a esa cuenta, pero César y Nacha deben estar presentes en videollamada mientras se toman, y cada uno saca sus propias capturas de conexión SSH y de sus consultas desde su propia pantalla.

| # | Captura requerida | Quién la saca | Qué debe mostrar |
|---|---|---|---|
| 1 | `terraform init` | Alex | Comando y resultado en la terminal |
| 2 | `terraform plan` | Alex | Listado de recursos a crear (los tres motores) |
| 3 | `terraform apply` | Alex | Comando, confirmación `yes` y resultado final |
| 4 | Instancias EC2 en consola AWS | Alex | Las 3 instancias en estado `running` |
| 5 | Conexión SSH a Cassandra + servicio activo | Alex | `ssh` exitoso y `systemctl status cassandra` / `nodetool status` |
| 6 | Conexión SSH a MongoDB + servicio activo | César | `ssh` exitoso y `systemctl status mongod` |
| 7 | Conexión SSH al cliente de DynamoDB + credenciales | Nacha | `ssh` exitoso y `aws sts get-caller-identity` |
| 8 | 3 consultas en Cassandra | Alex | Comandos CQL y resultados en `cqlsh` |
| 9 | 3 consultas en MongoDB | César | Comandos y resultados en `mongosh` |
| 10 | 3 consultas en DynamoDB | Nacha | Salida de `consultas_dynamodb.sh` (get-item, query, put-item) |
| 11 | Tabla DynamoDB en consola AWS | Alex | Tabla `streamvault_sesiones_activas` con sus datos |
| 12 | `terraform destroy` (cierre) | Alex | Comando y resultado final |

Cada uno guarda sus propias capturas (5-6-7 y 8-9-10 según corresponda) para pegarlas en su propio manual de evidencia; las capturas 1-4, 11 y 12 son las mismas para los tres, porque salen de la única cuenta donde se ejecutó todo.

## Mañana lunes — Informe escrito

Con las capturas ya listas, cada uno arma su propio documento de entrega: el mismo `main.tf`, el manual de evidencia con las capturas correspondientes, y sus propias respuestas a las 4 preguntas de análisis. Conviene discutir las 4 preguntas en conjunto antes de escribir, pero cada uno redacta su versión con sus propias palabras. Enviar con margen antes de las 23:59.
