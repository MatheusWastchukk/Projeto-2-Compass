# Projeto-2-Compass: Configuração AWS para WordPress com Docker e Auto Scaling

Este guia detalha o processo de configuração de uma infraestrutura AWS usando Docker para implantar o WordPress, incluindo Auto Scaling para melhor confiabilidade e desempenho.
![image](https://github.com/user-attachments/assets/96d994d1-2068-4dc4-a88e-4d1ec23ffa47)

## Índice
1. [Configuração da VPC](#1-configuração-da-vpc)
2. [Configuração do RDS MySQL](#2-configuração-do-rds-mysql)
3. [Configuração do EFS](#3-configuração-do-efs)
4. [Configuração das Instâncias EC2 com Docker](#4-configuração-das-instâncias-ec2-com-docker)
5. [Configuração do Load Balancer](#5-configuração-do-load-balancer)
6. [Configuração do Auto Scaling](#6-configuração-do-auto-scaling)
7. [Verificação e Testes](#7-verificação-e-testes)

## 1. Configuração da VPC

### 1.1. Criar VPC
- Acesse o serviço VPC no Console da AWS.
- Clique em "Criar VPC" e defina:
  - **Nome**: `projeto-2-compass-vpc`
  - **Bloco CIDR IPv4**: `10.0.0.0/16`
  - **Tenancy**: Padrão
- Clique em "Criar VPC" para finalizar.

### 1.2. Criar Subnets
Crie quatro subnets:

**Subnets Públicas**:
- **public-subnet-az1**:
  - VPC: `projeto-2-compass-vpc`
  - Zona de Disponibilidade: `us-east-1a`
  - Bloco CIDR IPv4: `10.0.1.0/24`
  
- **public-subnet-az2**:
  - VPC: `projeto-2-compass-vpc`
  - Zona de Disponibilidade: `us-east-1b`
  - Bloco CIDR IPv4: `10.0.2.0/24`

**Subnets Privadas**:
- **private-subnet-az1**:
  - VPC: `projeto-2-compass-vpc`
  - Zona de Disponibilidade: `us-east-1a`
  - Bloco CIDR IPv4: `10.0.3.0/24`

- **private-subnet-az2**:
  - VPC: `projeto-2-compass-vpc`
  - Zona de Disponibilidade: `us-east-1b`
  - Bloco CIDR IPv4: `10.0.4.0/24`

### 1.3. Criar Internet Gateway
- No console da VPC, vá para "Internet Gateways" e clique em "Criar Internet Gateway".
- Defina o nome como `projeto-2-compass-igw`.
- Após a criação, anexe o IGW à VPC `projeto-2-compass-vpc`.

### 1.4. Configurar Tabelas de Rotas
Crie duas tabelas de rotas:

- **public-rt** para subnets públicas
- **private-rt** para subnets privadas

Para **public-rt**:
- Adicione uma rota: Destino `0.0.0.0/0`, Alvo `projeto-2-compass-igw`
- Associe às subnets `public-subnet-az1` e `public-subnet-az2`

Para **private-rt**:
- Associe às subnets `private-subnet-az1` e `private-subnet-az2`

## 2. Configuração do RDS MySQL

### 2.1. Criar o Banco de Dados MySQL
- No console do RDS, clique em "Criar banco de dados".
- Configure:
  - **Engine**: MySQL
  - **Versão**: MySQL 8.0.28 (ou a mais recente estável)
  - **Modelo**: Gratuito
  - **Classe de instância**: `db.t3.micro`
  - **Nome do banco de dados**: `projeto-2-compass-db`
  - **VPC**: `projeto-2-compass-vpc`
  - **Subnet group**: Novo grupo com as subnets privadas
  - **Acesso público**: Não
  - **Security group**: Novo (`rds-sg`)
    - Regra de entrada: MySQL/Aurora (3306) do security group das instâncias EC2

## 3. Configuração do EFS (Elastic File System)

### 3.1. Criar EFS
- No console do EFS, clique em "Criar sistema de arquivos".
- Configure:
  - **Nome**: `projeto-2-compass-efs`
  - **VPC**: `projeto-2-compass-vpc`

Na seção de rede:
- Para cada zona de disponibilidade, selecione a subnet privada correspondente
- Crie um novo security group: `efs-sg`
  - Regra de entrada: NFS (2049) do security group das instâncias EC2

## 4. Configuração das Instâncias EC2 com Docker

### 4.1. Criar Security Group para EC2
- Crie um novo security group `ec2-sg` com as seguintes regras:

**Entrada**:
- HTTP (80) do security group do Load Balancer
- SSH (22) do seu IP local

**Saída**:
- MySQL (3306) para o security group do RDS
- NFS (2049) para o security group do EFS
- HTTP (80) e HTTPS (443) para qualquer lugar (`0.0.0.0/0`)

### 4.2. Criar Instâncias EC2
- Lance 2 instâncias com as seguintes configurações:
  - **AMI**: Amazon Linux 2
  - **Tipo**: `t2.micro`
  - **VPC**: `projeto-2-compass-vpc`
  - **Subnets**: Selecione as subnets privadas
  - **Auto-assign Public IP**: Desabilite
  - **Security Group**: `ec2-sg`

No campo de "User Data" da criação da instância EC2, adicione o seguinte script para instalar o Docker, rodar o WordPress e conectar ao EFS e ao RDS:

---

## 5. Configuração do Load Balancer

### 5.1. Criar Security Group para o Load Balancer

Crie um novo security group `lb-sg` com as seguintes regras de entrada:

- **HTTP (80)** de qualquer lugar (0.0.0.0/0)
- **HTTPS (443)** de qualquer lugar (0.0.0.0/0)

### 5.2. Criar o Application Load Balancer

No console EC2, crie um novo **Application Load Balancer**:

- **Nome**: `projeto-2-compass-lb`
- **Esquema**: Voltado para internet
- **VPC**: `projeto-2-compass-vpc`
- **Mapeamentos**: Selecione as duas subnets públicas
- **Security Group**: `lb-sg`

Configure **Listener** e **Target Group**:

- **Listener**: HTTP:80
- **Target Group**:
  - **Nome**: `projeto-2-compass-tg`
  - **Protocolo**: HTTP
  - **Porta**: 80
  - **Tipo de alvo**: Instâncias
  - **Health check path**: `/`

Registre as instâncias EC2 no Target Group.

---

## 6. Configuração do Auto Scaling

### 6.1. Criar Launch Template

No console EC2, crie um novo **Launch Template**:

- **Nome**: `projeto-2-compass-lt`
- **AMI**: Mesma das instâncias EC2
- **Tipo de instância**: `t2.micro`
- **Security Group**: `ec2-sg`
- **User data**: Use o mesmo script da seção 4.2

### 6.2. Criar Auto Scaling Group

Crie um novo **Auto Scaling Group**:

- **Nome**: `projeto-2-compass-asg`
- **Launch template**: `projeto-2-compass-lt`
- **VPC e subnets**: `projeto-2-compass-vpc` e subnets privadas
- **Load Balancing**: Ative e selecione o Target Group criado
- **Health check type**: ELB
- **Capacidade desejada**: 2
- **Capacidade mínima**: 2
- **Capacidade máxima**: 4

Adicione uma política de scaling dinâmico baseada em **CPU**:

- Aumente quando o uso médio da CPU for maior que 70% por 5 minutos
- Diminua quando o uso médio da CPU for menor que 30% por 5 minutos

---

## 7. Verificação e Testes

### 7.1. Verificar o Load Balancer

Copie o DNS do Load Balancer e acesse via navegador. A página de instalação do WordPress deve ser carregada.

### 7.2. Testar o Auto Scaling

1. Conecte-se a uma instância EC2 via SSH.
2. Execute: `sudo stress --cpu 8 --timeout 600`
3. Observe se novas instâncias são adicionadas.

### 7.3. Verificar a Persistência de Dados

1. Complete a instalação do WordPress.
2. Crie posts e faça upload de imagens.
3. Termine todas as instâncias EC2 e aguarde novas serem criadas.
4. Verifique se o conteúdo do WordPress permanece intacto.

---
