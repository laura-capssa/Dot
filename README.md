
# Modernização de Aplicação PHP com DevOps

##  Visão Geral
Este repositório implementa a modernização de uma aplicação web simples em PHP, conforme o desafio do teste técnico para Analista DevOps.  
A aplicação original é um "Hello World" em PHP. O foco é transformar o processo manual de deploy em uma abordagem automatizada e segura, usando **containerização**, **CI/CD** e **infraestrutura como código (IaC)**.

Minha solução cria uma fundação sólida:
- **Containerização**: Imagem Docker otimizada, multi-stage e segura.
- **CI**: Pipeline automatizado para build, análise de vulnerabilidades e push da imagem.
- **IaC e CD**: Provisionamento na AWS com Terraform e estratégia para deploy automático.
- **Observabilidade**: Plano de monitoramento com stack nativa AWS.

##  Estrutura do Repositório
```

├── .github/workflows/             # Pipeline CI com GitHub Actions
│   └── main.yml
├── app/                           # Código da aplicação PHP
│   └── index.php
├── ecs/                           # Definições ECS
│   └── task-definition.json
├── k8s/                           # Manifests Kubernetes (opcional)
│   ├── deployment.yaml
│   └── service.yaml
├── terraform/                     # Definições de infraestrutura IaC
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── variables.tf
├── Dockerfile                     # Imagem Docker da aplicação
└── README.md

````

---

## Etapa 1: Containerização da Aplicação

### Tarefa e Decisões
- **Imagem Base**: `php:8.2-fpm-alpine`. É oficial, leve e segura.
- **Multi-stage build**: `builder` (cópia do app) e `production` (imagem final com Apache + PHP-FPM).
- **Segurança**:  
  - Executa como usuário não-root (`USER 82`).  
  - Permissões ajustadas em `/var/www`.  
- **Configuração**: Apache configurado manualmente (módulos proxy_fcgi, rewrite, vhost).
- **Benefício**: Resolve o problema do "funciona na minha máquina", tornando o ambiente reprodutível em qualquer lugar.

### Teste Local
```bash
docker build -t php-hello-app .
docker run -p 8080:80 php-hello-app
````

Acesse [http://localhost:8080](http://localhost:8080).

---

## Etapa 2: Criação do Pipeline de Integração Contínua (CI)

### Tarefa e Decisões

Criei um pipeline no GitHub Actions (`.github/workflows/main.yml`) que roda a cada push na branch `main`.

* **Passos do Pipeline**:

  1. **Checkout do código**
  2. **Build da imagem Docker** (tag com SHA do commit)
  3. **Scan de vulnerabilidades com Trivy** (falha em `CRITICAL` ou `HIGH`)
  4. **Push para Docker Hub** (tags `commit_SHA` e `latest`)

* **Ferramentas**: GitHub Actions, Docker Buildx, Trivy.

* **Segredos Necessários**:

  * `DOCKER_USERNAME`
  * `DOCKER_PASSWORD`
    (configurados em Settings > Secrets do repositório GitHub)

### Como Executar

* Faça `git push origin main`.
* Acompanhe em **Actions > main.yml**.
* Se o scan falhar, atualize o Dockerfile ou a imagem base.

---

## Etapa 3: Infraestrutura como Código (IaC) e Implantação (CD)

### Escolha da Tecnologia

A escolha oficial foi **AWS ECS com Fargate**, pelas razões:

* Gerenciamento simplificado (serverless containers)
* Custos menores para workloads pequenos
* Integração nativa com ALB, IAM e CloudWatch

Incluí também:

* **Terraform para ECS** (infra básica com ALB, roles e serviço Fargate)
* **Código alternativo de EKS** (para cenários Kubernetes, apenas como demonstração)
* **Manifests K8s (k8s/)** para rodar localmente em Minikube

### Arquivos Terraform (`terraform/`)

* **provider.tf**: Configura o provider AWS (com flags para simulação local).
* **main.tf**: Define VPC, ECS Cluster, ALB, Task Definition e serviço Fargate.
* **variables.tf**: Variáveis (ex: `app_image`, `vpc_id`, `subnet_ids`).
* **outputs.tf**: Exporta o DNS do ALB (`app_url`).

### Manifestos

* **ECS**: `ecs/task-definition.json` (porta 80, logs no CloudWatch).
* **K8s (opcional)**: Deployment com probes e Service tipo LoadBalancer.

### Extensão para CD

O `main.yml` pode ser estendido com:

1. Configuração de credenciais AWS (`aws-actions/configure-aws-credentials`)
2. `terraform apply` para provisionar/atualizar
3. `ecs render-task-definition` + `ecs deploy-task-definition` para atualizar a imagem
4. Health check do ALB

**Estratégia:** Rolling update sem downtime, rollback manual se falhar.

---

## Etapa 4: Estratégia de Observabilidade

* **Stack escolhida**:

  * AWS CloudWatch (logs e métricas)
  * AWS X-Ray (tracing de requests PHP)
* **Por quê**: Simplicidade, cobrança sob demanda, integração automática com ECS.
* **Alternativa**: Prometheus + Grafana para reduzir custos em escala.

**3 Métricas principais para o dashboard:**

1. Latência de resposta (p95) no ALB
2. Utilização de CPU e memória no ECS
3. Erros HTTP 5xx

Alarmes via SNS notificam incidentes.

---

## Como Rodar o Projeto

### Localmente (Docker)

```bash
docker build -t php-hello-app .
docker run -p 8080:80 php-hello-app
```

### Pipeline CI

* Configure os secrets (`DOCKER_USERNAME`, `DOCKER_PASSWORD`)
* Faça `git push main`

### Terraform (simulação local)

```bash
cd terraform
terraform init
terraform validate
terraform plan \
  -var="vpc_id=vpc-fake123" \
  -var='subnet_ids=["subnet-fake1","subnet-fake2"]' \
  -var="app_image=laucapssa/php-hello-app:latest"
```

### Kubernetes local (opcional)

```bash
minikube start
kubectl apply -f k8s/
minikube service php-service
```

---

## Conclusão

Esta solução moderniza a aplicação PHP, substituindo deploys manuais por uma pipeline segura e infra automatizada.

* **Docker** garante portabilidade
* **CI com scan de segurança** reduz riscos
* **IaC + CD** acelera entregas e mantém consistência
* **Observabilidade** garante monitoramento da saúde

O repositório está pronto para evoluir conforme a aplicação cresce 

```
