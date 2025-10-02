# README - Modernização de Aplicação PHP com DevOps

## 🚀 Visão Geral
Este repositório implementa a modernização de uma aplicação web simples em PHP, conforme o desafio do teste técnico para Analista DevOps. A aplicação original é um "Hello World" em PHP, servida via Apache. O foco é transformar o processo manual de deploy em uma abordagem automatizada e segura, usando containerização, CI/CD e infraestrutura como código (IaC).

Atualmente, deploys manuais via SSH causam riscos e lentidão. Minha solução cria uma fundação sólida:
- **Containerização**: Imagem Docker otimizada.
- **CI**: Pipeline automatizado para build, teste e push.
- **IaC e CD**: Provisionamento na AWS com Terraform (escolhi ECS Fargate por simplicidade) e estratégia para deploy automático.
- **Observabilidade**: Plano para monitoramento em produção.

Escolhi ferramentas acessíveis e padrão do mercado, priorizando segurança, portabilidade e custo baixo. O pipeline roda em GitHub Actions, e a infra é provisionada na AWS. Como não tenho credenciais reais de AWS, configurei o Terraform para validação local com valores fake.

## 📂 Estrutura do Repositório
```
├── .github/workflows/             # Pipeline CI/CD com GitHub Actions
│ └── main.yml
├── app/                           # Código da aplicação PHP
│ └── index.php
├── docker-configs/                # Configurações adicionais do container
│ └── default.conf
├── k8s/                           # Manifests Kubernetes 
│ ├── deployment.yaml
│ ├── service.yaml
│ └── kubectl
├── terraform/                     # Definições de infraestrutura IaC
│ ├── main.tf
│ ├── outputs.tf
│ ├── provider.tf
│ └── variables.tf
├── Dockerfile                     # Imagem Docker da aplicação
├── task-definition.json           # Definições para orquestradores
└── README.md
```

## ✅ Etapa 1: Containerização da Aplicação

### Tarefa e Decisões
Criei um Dockerfile para containerizar a aplicação PHP. Usei uma imagem base oficial do PHP para garantir compatibilidade e segurança.

- **Imagem Base**: `php:8.2-apache` (versão LTS estável). É oficial, inclui Apache integrado e é adequada para apps web simples. Evitei imagens customizadas para reduzir riscos.
- **Otimização**: Implementei multi-stage build? Não diretamente, mas otimizei copiando apenas arquivos necessários e limpando cache para manter a imagem leve (cerca de 400MB final).
- **Segurança**: 
  - Execução como usuário não-root (`www-data`), para evitar privilégios elevados em caso de brechas.
  - Exposição apenas da porta 80.
  - Comentários no Dockerfile explicam cada layer: instalação de dependências mínimas, cópia do código para `/var/www/html`, e ajuste de permissões.
- **Por quê?** Isso resolve o problema de "funciona na minha máquina", tornando o ambiente reproduzível em qualquer lugar.

### Teste Local
Para testar o container localmente:
```bash
docker build -t php-hello-app -f docker/Dockerfile .
docker run -p 8080:80 php-hello-app
```
Acesse http://localhost:8080 no navegador. Deve mostrar "Hello World - Aplicação PHP rodando em container". Se der erro de permissão, verifique o usuário no Dockerfile.

## ✅ Etapa 2: Criação do Pipeline de Integração Contínua (CI)

### Tarefa e Decisões
Criei um pipeline CI no GitHub Actions (arquivo `.github/workflows/main.yml`) que roda a cada push na branch `main`. É acionado automaticamente e garante que só código validado avance.

- **Passos do Pipeline**:
  1. **Checkout do Código**: Baixa o repositório.
  2. **Build da Imagem Docker**: Constrói a imagem usando o Dockerfile, taggeada com o SHA do commit para rastreabilidade.
  3. **Análise de Vulnerabilidades**: Usa Trivy para escanear a imagem. Configurado para falhar se encontrar vulnerabilidades CRITICAL ou HIGH (severidade alta). Isso bloqueia pushes inseguros.
  4. **Push para Docker Hub**: Só na branch main, faz login seguro e publica a imagem com tags `${{ github.sha }}` e `latest`. Usa secrets do GitHub para autenticação (nunca expõe credenciais no código).

- **Ferramentas**: GitHub Actions (gratuito e integrado), Docker Buildx para build eficiente, Trivy (open-source, rápido para scans).
- **Segredos Necessários**: No GitHub, adicione `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN` (gere um token de acesso no Docker Hub, não a senha).
- **Por quê?** Automatiza testes e validações, reduzindo erros manuais. O scan de segurança é crucial para apps em produção, evitando deploys de imagens vulneráveis.

### Como Executar o Pipeline
- Faça um `git push` para a branch `main`.
- Acompanhe no GitHub: Actions > main.yml. Deve buildar, scanear e pushar se tudo OK.
- Se falhar no scan, corrija o Dockerfile (ex: atualize a base image).

## ✅ Etapa 3: Infraestrutura como Código (IaC) e Implantação (CD)

### Escolha da Tecnologia de Orquestração
Escolhi **AWS ECS com Fargate** em vez de EKS (Kubernetes) por estas razões:
- **Simplicidade**: Fargate gerencia os containers sem precisar configurar nós EC2 ou clusters complexos. Ideal para uma app simples e stateless como esta.
- **Custo e Overhead**: Mais barato para workloads pequenos (paga só pelo tempo de execução). EKS adiciona complexidade desnecessária para um MVP.
- **Integração AWS**: Nativo da AWS, fácil de escalar com ALB e CloudWatch.
- **Justificativa Geral**: Para crescimento acelerado, Fargate permite foco no app, não na infra. Se a app evoluir para microservices, migrar para EKS seria viável.

Incluí manifests alternativos para Kubernetes (deployment.yaml e service.yaml) na pasta `k8s/`, caso prefiram testar localmente com Minikube.

### Código Terraform (Pasta `infra/terraform/`)
Os arquivos Terraform provisionam uma infraestrutura básica e idempotente na AWS:
- **providers.tf**: Configura o provider AWS (região us-east-1). Para testes sem credenciais reais, adicionei flags como `skip_credentials_validation = true` e chaves fake.
- **main.tf**: Define:
  - VPC e subnets (públicas/privadas para isolamento).
  - Cluster ECS e roles IAM (com permissões mínimas).
  - Application Load Balancer (ALB) para distribuir tráfego.
  - Task Definition (referencia a imagem do Docker Hub).
  - Serviço ECS Fargate (roda 1 task, porta 80, auto-scaling básico).
- **variables.tf**: Variáveis como `app_image` (ex: `laucapssa/php-hello-app:latest`), `vpc_id` e `subnet_ids`.
- **outputs.tf**: Exporta o DNS do ALB (ex: `app_url`) para acessar a app após deploy.

Isso garante ambientes idênticos (dev/prod) e rastreabilidade via Git.

### Manifestos para Implantação
- **ECS**: `ecs/task-definition.json` define o container (`php-app`), porta 80, logs para CloudWatch e variáveis de ambiente. Integra com o Terraform.
- **Kubernetes (Opcional)**: `k8s/deployment.yaml` cria um Deployment com 2 réplicas, probes de health (liveness/readiness na porta 80). `k8s/service.yaml` expõe via LoadBalancer.

### Explicação do CD (Extensão do Pipeline CI)
Para transformar o CI em CD, estenderia o `main.yml` adicionando um job final "Deploy" após o push da imagem. Isso roda só na branch `main` e em ambiente de produção (usando approvals no GitHub).

- **Passos do CD**:
  1. **Configurar Credenciais AWS**: Usar a action `aws-actions/configure-aws-credentials` com secrets `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` (IAM com role de deploy, curta duração).
  2. **Terraform Apply**: No diretório `infra/terraform`, rode `terraform init`, `plan` (com vars como imagem taggeada) e `apply -auto-approve`. Isso provisiona/atualiza a infra se necessário.
  3. **Atualizar e Deployar no ECS**: 
     - Use `aws-actions/amazon-ecs-render-task-definition` para atualizar a task definition com a nova imagem (tag SHA).
     - Em seguida, `aws-actions/amazon-ecs-deploy-task-definition` para forçar o deploy no serviço ECS, esperando estabilidade.
  4. **Health Check**: Rode comandos AWS CLI para verificar tasks saudáveis e o URL do ALB. Adicione sleep e curl para testar o endpoint.

- **Estratégia de Implantação**: Rolling updates no ECS (zero downtime). Em falha, rollback manual via AWS Console ou Terraform destroy/apply anterior.
- **Por quê?** Cada push na main resulta em deploy automático, reduzindo tempo de semanas para minutos. Integra com o CI existente, mantendo scans de segurança.

### Validação do Terraform (Sem AWS Real)
```bash
cd infra/terraform
terraform init
terraform validate
terraform plan \
  -var="vpc_id=vpc-fake123" \
  -var='subnet_ids=["subnet-fake1", "subnet-fake2"]' \
  -var="app_image=laucapssa/php-hello-app:latest"
```
Isso simula o plan sem custos. Em produção, use IDs reais e credenciais.

## ✅ Etapa 4: Estratégia de Observabilidade

### Stack de Ferramentas Escolhida
Escolheria a stack nativa da AWS para simplicidade e integração: **CloudWatch + AWS X-Ray**. 
- **CloudWatch**: Para logs (do container) e métricas (CPU, memória, tráfego).
- **AWS X-Ray**: Para tracing de requests (útil em PHP para depurar latência).
- **Por quê?** É serverless, sem setup extra, e cobra só pelo uso. Para apps PHP em ECS, integra automaticamente via agent no task definition. Evita custos de ferramentas third-party como Prometheus/Grafana inicialmente; posso adicionar depois se precisar de dashboards customizados.

Alternativa para Economia de Custos
Para otimizar custos a longo prazo, especialmente se o volume de métricas e logs crescer e o CloudWatch se tornar caro (devido a taxas de ingestão e armazenamento), eu consideraria migrar para uma stack open-source como Prometheus para coleta de métricas e Grafana para visualização e dashboards. O Prometheus pode ser rodado como um container no próprio ECS Fargate (com scraping automático das métricas do app PHP via exporters como o Node Exporter ou Blackbox para endpoints HTTP), e o Grafana hospedado em uma instância EC2 t3.micro barata (cerca de US$ 5/mês). Essa abordagem elimina as taxas de dados do CloudWatch, mantendo a flexibilidade para alertas e queries avançadas, e é escalável sem lock-in na AWS – ideal para um crescimento acelerado onde os custos precisam ser controlados.

### 3 Principais Métricas para o Dashboard de Saúde
Usaria CloudWatch Dashboards para monitorar essas métricas chave, focando em UX, estabilidade e recursos:
1. **Latência de Resposta (TargetResponseTime)**: Tempo médio/p95 de requests no ALB ou container. Justificativa: Detecta lentidão na app PHP (ex: picos de usuários), impactando a experiência. Alarme se > 500ms.
2. **Utilização de CPU/Memória (CPUUtilization e MemoryUtilization)**: % de uso no serviço ECS. Justificativa: Previne sobrecarga; auto-scaling pode adicionar tasks se > 70%. Essencial para crescimento acelerado sem downtime.
3. **Erros HTTP (HTTPCode_Target_5XX_Count)**: Contagem de erros 5xx no target group do ALB. Justificativa: Indica falhas na app (ex: crashes PHP). Alarme imediato para rollback, garantindo estabilidade em produção.

Essas métricas seriam coletadas a cada 1-5 minutos, com alarmes via SNS para notificações.

## 🔍 Como Rodar o Projeto

### Localmente (Docker)
```bash
docker build -t php-hello-app -f docker/Dockerfile .
docker run -p 8080:80 php-hello-app
```
Acesse http://localhost:8080.

### Pipeline CI (GitHub Actions)
- Adicione secrets no repositório (Settings > Secrets).
- `git push origin main` – Verifique em Actions.

### Infraestrutura (Terraform - Teste Local)
Use o comando de validação acima. Para deploy real:
```bash
cd infra/terraform
terraform init
terraform apply -var="app_image=laucapssa/php-hello-app:latest" -auto-approve
```
Acesse o output `app_url` no navegador.

### Kubernetes Local (Opcional, com Minikube)
```bash
minikube start
kubectl apply -f k8s/
minikube service php-service
```

## 📌 Conclusão
Esta solução moderniza o ciclo de vida da aplicação PHP, resolvendo gargalos de deploy manual com automação segura e escalável. O CI garante qualidade, o IaC mantém consistência, e o CD (pronto para extensão) acelera lançamentos. A observabilidade foca no essencial para monitorar saúde. Como DevOps junior, priorizei práticas básicas mas eficazes, como scans e não-root, para um crescimento sustentável. O repositório é pronto para evoluir – sugestões bem-vindas! 🚀