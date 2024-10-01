# Projeto-2-Compass

Configurando uma estrura AWS, com docker para utilizar o wordpress.
![image](https://github.com/user-attachments/assets/96d994d1-2068-4dc4-a88e-4d1ec23ffa47)

## 1. Configuração da VPC Personalizada

### 1.1. Criar VPC
1. No Console da AWS, acesse o serviço **VPC** e clique em "Criar VPC".
2. Defina as seguintes configurações:
   - **Nome:** `projeto-2-compass-vpc`
   - **Bloco CIDR:** `10.0.0.0/16`
   - **Tenancy:** Padrão
3. Clique em "Criar VPC".

### 1.2. Criar Subnets
1. Crie duas subnets públicas em diferentes Zonas de Disponibilidade (AZs):
   - **public-subnet-az1**: CIDR `10.0.1.0/24`, Zona de Disponibilidade `us-east-1a`.
   - **public-subnet-az2**: CIDR `10.0.2.0/24`, Zona de Disponibilidade `us-east-1b`.
   
2. Crie duas subnets privadas em diferentes Zonas de Disponibilidade:
   - **private-subnet-az1**: CIDR `10.0.3.0/24`, Zona de Disponibilidade `us-east-1a`.
   - **private-subnet-az2**: CIDR `10.0.4.0/24`, Zona de Disponibilidade `us-east-1b`.

### 1.3. Criar um Internet Gateway (IGW)
1. No console da VPC, vá para "Internet Gateways" e clique em "Criar Internet Gateway".
2. Nomeie o gateway como `projeto-2-compass-igw` e associe-o à VPC `projeto-2-compass-vpc`.
   
### 1.4. Configurar a Tabela de Rotas
1. Edite a **Tabela de Rotas** da **VPC** e associe o **Internet Gateway** à rota de saída para a internet (0.0.0.0/0) nas **subnets públicas**.
2. Para as subnets privadas, crie uma rota para o **NAT Gateway** (criado previamente) para permitir acesso à internet.

---

## 2. Configuração do RDS MySQL

### 2.1. Criar o Banco de Dados MySQL
1. Acesse o console do **RDS** e clique em "Criar banco de dados".
2. Selecione:
   - **Engine:** MySQL
   - **Classe:** `db.t3.micro`
   - **Nome do banco:** `projeto-2-compass-db`
   - **Usuário e senha:** Defina conforme necessário.
3. Escolha o **Subnet Group** com as **subnets privadas** (private-subnet-az1 e private-subnet-az2).
4. Configure o **Security Group**:
   - **Entrada (Inbound):** Permitir tráfego na porta **3306** apenas do **Security Group das instâncias EC2**.

---

## 3. Configuração do EFS (Elastic File System)

### 3.1. Criar EFS
1. Acesse o console do **EFS** e clique em "Criar sistema de arquivos".
2. Nomeie como `projeto-2-compass-efs` e selecione a **VPC projeto-2-compass-vpc**.
3. Adicione **Mount Targets** para as duas **subnets privadas** (private-subnet-az1 e private-subnet-az2).

### 3.2. Configurar o Security Group para EFS
1. Crie um **Security Group** chamado `efs-sg`.
2. Permitir tráfego nas portas **2049** (NFS) apenas das **instâncias EC2**.

---

## 4. Configuração das Instâncias EC2 com Docker

### 4.1. Criar Instâncias EC2
1. Acesse o console **EC2** e crie duas instâncias nas **subnets privadas**.
   - **Tipo:** t2.micro (para testes).
   - **Sistema Operacional:** Amazon Linux 2.
   - **Security Group:**
     - **Entrada (Inbound):**
       - Permitir tráfego **HTTP** (porta 80 ou 8080) do **Load Balancer**.
       - Permitir tráfego **SSH** (porta 22) do seu IP local.
     - **Saída (Outbound):**
       - Permitir tráfego **MySQL** (porta 3306) para o **RDS**.
       - Permitir tráfego **NFS** (porta 2049) para o **EFS**.
       
### 4.2. Script de User Data para Instâncias EC2
No campo de "User Data" da criação da instância EC2, adicione o seguinte script para instalar o Docker, rodar o WordPress e conectar ao EFS:

```bash
