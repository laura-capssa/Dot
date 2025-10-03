
# Modernização de Aplicação PHP com DevOps

##  Visão Geral
Este repositório implementa a modernização de uma aplicação web simples em PHP, conforme o desafio do teste técnico para Analista DevOps.  
A aplicação original é um "Hello World" em PHP. O foco é transformar o processo manual de deploy em uma abordagem automatizada e segura, usando **containerização**, **CI/CD** e **infraestrutura como código (IaC)**.

Minha solução cria uma fundação sólida:
- **Containerização**: Imagem Docker otimizada, multi-stage e segura.
- **CI**: Pipeline automatizado para build, análise de vulnerabilidades e push da imagem.
- **IaC e CD**: Provisionamento na AWS com Terraform e estratégia para deploy automático.
- **Observabilidade**: Plano de monitoramento nativa AWS além de uma segund aopção mais em conta, utilizando Prometheus e Grafana.

##  Estrutura do Repositório
```

├── .github/workflows/             # Pipeline CI com GitHub Actions
│   └── main.yml
├── app/                           # Código da aplicação PHP
│   └── index.php
├── ecs/                           # Definições ECS
│   └── task-definition.json
├── k8s/                           # Manifests Kubernetes
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

###  Como funcionaria o CD

**Configuração das credenciais da AWS**  
O pipeline teria acesso a um usuário IAM com permissões mínimas para ECS, Fargate e Terraform. Assim, cada execução teria autorização controlada para atualizar a infraestrutura.  

**Provisionamento ou atualização da infraestrutura**  
O Terraform seria executado dentro do pipeline para garantir que a infraestrutura esteja criada ou atualizada, mantendo consistência entre ambientes (dev, teste e produção).  

**Atualização da aplicação no ECS Fargate**  
Após o build da nova imagem, a definição da tarefa seria atualizada para usar a imagem mais recente publicada no Docker Hub. O serviço ECS aplicaria essa nova configuração.  

**Deploy automatizado com estratégia segura**  
O ECS faria um *rolling update*, substituindo gradualmente as tasks antigas pelas novas, sem downtime. Durante esse processo, apenas versões saudáveis da aplicação seriam mantidas em execução.  

**Health check e verificação**  
Após o deploy, seria feita uma checagem automática para confirmar se a aplicação está respondendo corretamente no Load Balancer (ALB). Caso algo falhe, é possível acionar um rollback para a versão anterior.  

---

## Etapa 4: Estratégia de Observabilidade


### Opção 1: AWS CloudWatch (Solução Gerenciada)

**Componentes Principais:**
- **CloudWatch Logs**: Coleta centralizada de logs da aplicação e infraestrutura
- **CloudWatch Metrics**: Monitoramento de métricas de performance e recursos
- **AWS X-Ray**: Rastreamento distribuído para analisar o journey completo das requisições PHP
- **CloudWatch Canaries**: Sistema de alertas inteligentes com múltiplas condições
- **SNS**: Notificações em tempo real para a equipe

**Vantagens:**
- Integração nativa com todos serviços AWS
- Configuração mínima e rápida implementação
- Modelo de custo sob demanda
- Alta disponibilidade gerenciada pela AWS
- Zero manutenção de infraestrutura

---

### Opção 2: Prometheus + Grafana (Solução Open Source)

**Componentes Principais:**
- **Prometheus**: Coleta e armazenamento de métricas com query language poderosa
- **Grafana**: Visualização através de dashboards altamente customizáveis
- **Alertmanager**: Sistema de gerenciamento de alertas
- **Node Exporter**: Coleta de métricas de nível de sistema operacional

**Vantagens:**
- Redução significativa de custos em ambiente de grande escala
- Flexibilidade total para customizações específicas
- Controle completo sobre retenção e processamento de dados
- Comunidade ativa e suporte colaborativo

---

## Métricas Principais para Dashboard

### 1. Latência de Resposta
- Representa a experiência real do usuário final. Enquanto a média pode mascarar problemas, o p95 revela como os usuários mais impactados estão experienciando a aplicação.

### 2. Utilização de Recursos 
- Prevenção proativa de gargalos e otimização de custos. Monitorar tendências ajuda no planejamento de capacidade e identificação de memory leaks.

### 3. Taxa de Erros HTTP
- Indicador direto da saúde da aplicação. Erros 5xx representam falhas do lado do servidor que impactam diretamente a experiência do usuário

---

## Sistema de Alarmes e Notificações

**Estratificação por Severidade:**
- **Crítico:** Notificações imediatas via SMS e email para o time de plantão
- **Alerta:** Notificações por email para o time de desenvolvimento
- **Informativo:** Notificações em canais de comunicação corporativos

---

##  Dashboard de Saúde da Aplicação

### Seção de Performance do Usuário
- Visualização em tempo real do tempo de resposta
- Comparativo entre percentis (p50, p95, p99)
- Taxa de requisições bem-sucedidas versus com erro
- Mapas de calor de performance por região geográfica

### Seção de Saúde da Infraestrutura
- Utilização de recursos em formato de tendência
- Capacidade disponível versus utilizada
- Métricas de rede e operações de I/O
- Correlação entre métricas de infraestrutura e performance

### Seção de Métricas de Negócio
- Disponibilidade do serviço em porcentagem
- Conformidade com SLAs estabelecidos
- Impacto estimado em usuários durante incidentes
- Tempo médio entre falhas e tempo médio de recuperação
- 
---

## Resposta a Incidentes

**Cenário: Alta Latência**
1. Verificar se o aumento é generalizado ou específico
2. Correlacionar com métricas de recursos
3. Analisar traces para identificar gargalos
4. Escalar recursos ou otimizar código conforme necessário

**Cenário: Aumento de Erros 5xx**
1. Identificar padrões temporais ou geográficos
2. Correlacionar com deploys recentes
3. Verificar health checks e dependências
4. Implementar rollback se necessário

**Cenário: Alta Utilização de Recursos**
1. Diferenciar entre uso legítimo e problemas
2. Identificar processos ou funcionalidades específicas
3. Analisar queries de banco e chamadas externas
4. Escalar horizontalmente ou otimizar

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

O repositório está pronto para evoluir conforme a aplicação cresce 🚀

```
