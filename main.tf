# StreamVault - infra NoSQL para el Learner Lab (Certamen 1)
# Cassandra (historial reproducciones) + MongoDB (catalogo/usuarios) + DynamoDB (sesiones activas)
#
# Ojo: en el Learner Lab solo existe LabRole, no se crean IAM roles nuevos.
# Credenciales se toman de ~/.aws/credentials, no van en este archivo. Si expiran
# a mitad de sesion hay que refrescarlas y volver a aplicar.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables

variable "aws_region" {
  description = "Region de AWS usada por el Learner Lab"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Nombre del key pair existente en el Learner Lab"
  type        = string
  default     = "vockey"
}

variable "instance_type_db" {
  description = "Tipo de instancia para Cassandra y MongoDB"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_client" {
  description = "Tipo de instancia para el cliente de DynamoDB (no requiere motor propio)"
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "Rango de IPs permitido para SSH. Restringir a la IP del grupo en un entorno real."
  type        = string
  default     = "0.0.0.0/0"
}

# Red y AMIs por defecto

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # us-east-1e no soporta varios tipos de instancia (t3.medium incl.) en varias
  # cuentas del Learner Lab. Se excluye para no depender de qué subnet caiga
  # primero en data.aws_subnets.default.ids[0].
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security group compartido por las 3 instancias

resource "aws_security_group" "streamvault_sg" {
  name        = "streamvault-sg"
  description = "SSH y puertos nativos de Cassandra y MongoDB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Cassandra - protocolo nativo (CQL)"
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Salida abierta"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "streamvault-sg"
    Proyecto = "StreamVault"
  }
}

# 1) Cassandra - historial de reproducciones / eventos de usuario

resource "aws_instance" "cassandra" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_db
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.streamvault_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    exec > /var/log/user-data.log 2>&1

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y openjdk-11-jdk wget gnupg curl

    # Repositorio oficial de Apache Cassandra (rama 4.1.x)
    wget -q -O - https://downloads.apache.org/cassandra/KEYS | gpg --dearmor -o /usr/share/keyrings/cassandra-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cassandra-archive-keyring.gpg] https://debian.cassandra.apache.org 41x main" > /etc/apt/sources.list.d/cassandra.sources.list

    apt-get update -y
    apt-get install -y cassandra

    # Vincular Cassandra a la IP privada de la instancia
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    sed -i "s/^listen_address:.*/listen_address: $PRIVATE_IP/" /etc/cassandra/cassandra.yaml
    sed -i "s/^rpc_address:.*/rpc_address: 0.0.0.0/" /etc/cassandra/cassandra.yaml
    sed -i "s/^# broadcast_rpc_address:.*/broadcast_rpc_address: $PRIVATE_IP/" /etc/cassandra/cassandra.yaml

    systemctl enable cassandra
    systemctl restart cassandra

    # Esperar a que Cassandra levante (hasta ~5 minutos)
    for i in $(seq 1 30); do
      if cqlsh -e "DESCRIBE KEYSPACES" > /dev/null 2>&1; then
        break
      fi
      sleep 10
    done

    cqlsh -e "
    CREATE KEYSPACE IF NOT EXISTS streamvault
    WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

    CREATE TABLE IF NOT EXISTS streamvault.historial_reproducciones (
      user_id           text,
      evento_timestamp  timestamp,
      movie_id          text,
      evento_tipo       text,
      duracion_segundos int,
      dispositivo       text,
      pais              text,
      PRIMARY KEY (user_id, evento_timestamp)
    ) WITH CLUSTERING ORDER BY (evento_timestamp DESC);

    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_001', '2026-07-10T20:15:00.000+0000', 'movie_101', 'play', 5400, 'smart_tv', 'CL');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_001', '2026-07-11T21:00:00.000+0000', 'movie_205', 'play', 3600, 'mobile', 'CL');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_001', '2026-07-11T22:05:00.000+0000', 'movie_205', 'pause', 0, 'mobile', 'CL');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_002', '2026-07-12T18:30:00.000+0000', 'movie_101', 'play', 5400, 'smart_tv', 'MX');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_002', '2026-07-13T19:00:00.000+0000', 'movie_310', 'play', 2700, 'laptop', 'MX');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_003', '2026-07-14T22:45:00.000+0000', 'movie_205', 'play', 3600, 'smart_tv', 'AR');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_003', '2026-07-15T10:00:00.000+0000', 'movie_101', 'resume', 5400, 'tablet', 'AR');
    INSERT INTO streamvault.historial_reproducciones (user_id, evento_timestamp, movie_id, evento_tipo, duracion_segundos, dispositivo, pais)
      VALUES ('user_003', '2026-07-16T09:15:00.000+0000', 'movie_310', 'stop', 900, 'tablet', 'AR');
    "
    EOF

  tags = {
    Name     = "streamvault-cassandra"
    Motor    = "Apache Cassandra"
    Proyecto = "StreamVault"
  }
}

# 2) MongoDB - catalogo de peliculas, perfiles y favoritos

resource "aws_instance" "mongodb" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_db
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.streamvault_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    exec > /var/log/user-data.log 2>&1

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y gnupg curl

    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list

    apt-get update -y
    apt-get install -y mongodb-org

    sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" /etc/mongod.conf

    systemctl enable mongod
    systemctl restart mongod

    for i in $(seq 1 15); do
      if mongosh --quiet --eval "db.runCommand({ ping: 1 })" > /dev/null 2>&1; then
        break
      fi
      sleep 10
    done

    cat << 'JS' > /tmp/seed.js
    db = db.getSiblingDB('streamvault');

    db.peliculas.insertMany([
      { movie_id: "movie_101", titulo: "Cordillera Nocturna", genero: ["drama", "thriller"], anio: 2023, duracion_min: 118, rating: 8.1, plataformas: ["web", "smart_tv", "mobile"] },
      { movie_id: "movie_205", titulo: "El Ultimo Verano", genero: ["comedia", "romance"], anio: 2021, duracion_min: 102, rating: 7.4, plataformas: ["web", "mobile"] },
      { movie_id: "movie_310", titulo: "Frontera Digital", genero: ["ciencia ficcion"], anio: 2024, duracion_min: 135, rating: 8.6, plataformas: ["web", "smart_tv", "mobile", "tablet"] },
      { movie_id: "movie_412", titulo: "Ruta 40", genero: ["documental"], anio: 2020, duracion_min: 89, rating: 7.9, plataformas: ["web"] },
      { movie_id: "movie_530", titulo: "Sombras del Sur", genero: ["terror", "thriller"], anio: 2022, duracion_min: 97, rating: 6.8, plataformas: ["web", "mobile"] }
    ]);

    db.usuarios.insertMany([
      { user_id: "user_001", nombre: "Camila Rios", email: "camila.rios@example.com", pais: "CL", plan: "premium", fecha_registro: new Date("2022-03-14"), favoritos: ["movie_101", "movie_310"] },
      { user_id: "user_002", nombre: "Diego Fernandez", email: "diego.fernandez@example.com", pais: "MX", plan: "basico", fecha_registro: new Date("2023-01-05"), favoritos: ["movie_205"] },
      { user_id: "user_003", nombre: "Valentina Suarez", email: "valentina.suarez@example.com", pais: "AR", plan: "premium", fecha_registro: new Date("2021-11-20"), favoritos: ["movie_101", "movie_205", "movie_412"] }
    ]);
    JS

    mongosh streamvault --file /tmp/seed.js
    EOF

  tags = {
    Name     = "streamvault-mongodb"
    Motor    = "MongoDB"
    Proyecto = "StreamVault"
  }
}

# 3) DynamoDB - sesiones activas (servicio gestionado, no requiere EC2 propia)

resource "aws_dynamodb_table" "sesiones_activas" {
  name         = "streamvault_sesiones_activas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "user_id-index"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  tags = {
    Name     = "streamvault-sesiones-activas"
    Motor    = "DynamoDB"
    Proyecto = "StreamVault"
  }
}

resource "aws_dynamodb_table_item" "sesion_1" {
  table_name = aws_dynamodb_table.sesiones_activas.name
  hash_key   = aws_dynamodb_table.sesiones_activas.hash_key

  item = <<ITEM
{
  "session_id": {"S": "sess_0001"},
  "user_id": {"S": "user_001"},
  "dispositivo": {"S": "smart_tv"},
  "pais": {"S": "CL"},
  "inicio_sesion": {"S": "2026-07-17T20:00:00Z"},
  "estado": {"S": "activa"}
}
ITEM
}

resource "aws_dynamodb_table_item" "sesion_2" {
  table_name = aws_dynamodb_table.sesiones_activas.name
  hash_key   = aws_dynamodb_table.sesiones_activas.hash_key

  item = <<ITEM
{
  "session_id": {"S": "sess_0002"},
  "user_id": {"S": "user_001"},
  "dispositivo": {"S": "mobile"},
  "pais": {"S": "CL"},
  "inicio_sesion": {"S": "2026-07-17T21:10:00Z"},
  "estado": {"S": "activa"}
}
ITEM
}

resource "aws_dynamodb_table_item" "sesion_3" {
  table_name = aws_dynamodb_table.sesiones_activas.name
  hash_key   = aws_dynamodb_table.sesiones_activas.hash_key

  item = <<ITEM
{
  "session_id": {"S": "sess_0003"},
  "user_id": {"S": "user_002"},
  "dispositivo": {"S": "laptop"},
  "pais": {"S": "MX"},
  "inicio_sesion": {"S": "2026-07-17T19:45:00Z"},
  "estado": {"S": "activa"}
}
ITEM
}

resource "aws_dynamodb_table_item" "sesion_4" {
  table_name = aws_dynamodb_table.sesiones_activas.name
  hash_key   = aws_dynamodb_table.sesiones_activas.hash_key

  item = <<ITEM
{
  "session_id": {"S": "sess_0004"},
  "user_id": {"S": "user_003"},
  "dispositivo": {"S": "tablet"},
  "pais": {"S": "AR"},
  "inicio_sesion": {"S": "2026-07-17T18:30:00Z"},
  "estado": {"S": "expirada"}
}
ITEM
}

resource "aws_dynamodb_table_item" "sesion_5" {
  table_name = aws_dynamodb_table.sesiones_activas.name
  hash_key   = aws_dynamodb_table.sesiones_activas.hash_key

  item = <<ITEM
{
  "session_id": {"S": "sess_0005"},
  "user_id": {"S": "user_002"},
  "dispositivo": {"S": "smart_tv"},
  "pais": {"S": "MX"},
  "inicio_sesion": {"S": "2026-07-17T22:00:00Z"},
  "estado": {"S": "activa"}
}
ITEM
}

# Instancia cliente: no instala DynamoDB (es un servicio gestionado), solo
# actua como punto desde donde se ejecutan comandos de AWS CLI contra la tabla.
resource "aws_instance" "dynamo_client" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type_client
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.streamvault_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    exec > /var/log/user-data.log 2>&1

    dnf install -y jq

    mkdir -p /home/ec2-user/queries
    cat << 'SH' > /home/ec2-user/queries/consultas_dynamodb.sh
    #!/bin/bash
    # Antes de correr este script hay que configurar las credenciales del
    # Learner Lab en ~/.aws/credentials dentro de esta instancia.
    set -e
    TABLE="streamvault_sesiones_activas"

    echo "Consulta 1: obtener una sesion por session_id (get-item)"
    aws dynamodb get-item --table-name "$TABLE" \
      --key '{"session_id": {"S": "sess_0001"}}'

    echo "Consulta 2: listar las sesiones activas de un usuario (query sobre el GSI)"
    aws dynamodb query --table-name "$TABLE" \
      --index-name "user_id-index" \
      --key-condition-expression "user_id = :uid" \
      --expression-attribute-values '{":uid": {"S": "user_001"}}'

    echo "Consulta 3: insertar una nueva sesion activa (put-item)"
    aws dynamodb put-item --table-name "$TABLE" \
      --item '{
        "session_id": {"S": "sess_0006"},
        "user_id": {"S": "user_003"},
        "dispositivo": {"S": "mobile"},
        "pais": {"S": "AR"},
        "inicio_sesion": {"S": "2026-07-17T23:00:00Z"},
        "estado": {"S": "activa"}
      }'
    SH

    chmod +x /home/ec2-user/queries/consultas_dynamodb.sh
    chown -R ec2-user:ec2-user /home/ec2-user/queries
    EOF

  tags = {
    Name     = "streamvault-dynamodb-client"
    Motor    = "DynamoDB (cliente AWS CLI)"
    Proyecto = "StreamVault"
  }
}

# Outputs

output "cassandra_public_ip" {
  description = "IP publica de la instancia de Cassandra"
  value       = aws_instance.cassandra.public_ip
}

output "mongodb_public_ip" {
  description = "IP publica de la instancia de MongoDB"
  value       = aws_instance.mongodb.public_ip
}

output "dynamo_client_public_ip" {
  description = "IP publica de la instancia cliente de DynamoDB"
  value       = aws_instance.dynamo_client.public_ip
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB de sesiones activas"
  value       = aws_dynamodb_table.sesiones_activas.name
}
