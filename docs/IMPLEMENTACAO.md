# Implementação e implantação – Sistema de Gestão de Eventos e Auditórios

Implementação do projeto da disciplina (Mackenzie – Sistemas de Informação), conforme os requisitos RF01–RF11, casos de uso UC01–UC16 e regras RN01–RN10 da especificação.

## Arquitetura

```
 React (Vite, TS) ──token JWT──▶ Spring Boot (API REST, Java 21) ──JDBC──▶ PostgreSQL (Supabase)
        │                               │
        └───── login (OIDC/PKCE) ───▶ Keycloak ◀── valida JWT (issuer/JWKS)
```

| Camada | Tecnologia | Pasta |
|---|---|---|
| Front-end | React 18 + Vite + TypeScript, `keycloak-js` | `frontend/` |
| Back-end | Spring Boot 3.3, Spring Security (OAuth2 Resource Server), JDBC | `backend/` |
| Identidade | Keycloak 26 (realm `eventos`, roles `ADMIN` e `PARTICIPANTE`) | `keycloak/`, `docker-compose.yml` |
| Banco | PostgreSQL 17 no Supabase (projeto `gestao-eventos-auditorios`, região sa-east-1) | `db/` |

A comparação com o diagrama de arquitetura do Moodle está na seção *Aderência ao diagrama do Moodle*, mais abaixo.

### Onde cada regra mora
As regras de negócio ficam no **banco**, em funções transacionais (`db/migrations/002_funcoes.sql`), para valer mesmo com acessos simultâneos (RNF04):

| Regra | Implementação |
|---|---|
| RN01/RN02 – sem conflito de local/horário | trigger `eventos_validar` + *exclusion constraints* (`gist`) |
| RN03/RN04 – confirmar enquanto houver vaga; lotou → fila | `fn_inscrever` (trava a linha do evento com `FOR UPDATE`) |
| RN05 – ordem da fila preservada | coluna `inscricoes.ordem` (identity) + `fn_promover_fila` |
| RN06 – sem inscrição duplicada | índice único parcial `inscricoes_unica_ativa` |
| RN07/RN08 – check-in só do inscrito, uma vez | `fn_registrar_checkin` + `unique(inscricao_id)` |
| RNF07 – check-in imutável | trigger `checkins_imutavel` |
| RN09/RN10 – certificado só com presença, código único | `fn_emitir_certificado`, `certificados.codigo_verificacao` (64 hex aleatórios) |
| RNF06 – permissão no servidor | `@PreAuthorize("hasRole('ADMIN')")` + RLS ligado e sem acesso para `anon`/`authenticated` |

O back-end traduz os erros do banco (`EVENTO_LOTADO`, `CONFLITO_AGENDA`, …) em respostas HTTP (`ApiExceptionHandler`).

## Como executar

### 1. Banco (Supabase) – já criado
As migrations de `db/migrations/` **já foram aplicadas** no projeto `gestao-eventos-auditorios` (`mirmpnbpbdvwixqxyptm`) e os 3 locais iniciais já foram cadastrados. Para recriar em outro projeto, rode `001`, `002`, `003` e `seed.sql`, nessa ordem, no SQL Editor.

Defina/anote a **senha do banco** em *Project Settings → Database → Reset database password*.

### 2. Keycloak
```bash
docker compose up -d        # http://localhost:8180  (admin / admin)
```
O realm `eventos` é importado automaticamente, com dois usuários de teste:

| Usuário | Senha | Perfil |
|---|---|---|
| `organizador` | `admin123` | Administrador/Organizador |
| `aluno` | `aluno123` | Participante |

Novos participantes podem se cadastrar na própria tela de login.

### 3. Back-end
```bash
cd backend
cp .env.example .env        # preencha DB_PASSWORD (e DB_URL, se usar o pooler)
export $(grep -v '^#' .env | xargs)
mvn spring-boot:run         # http://localhost:8080
```
Requer Java 21 e Maven.

### 4. Front-end
```bash
cd frontend
cp .env.example .env
npm install
npm run dev                 # http://localhost:5173
```

## Principais endpoints (todos exigem token JWT)

| Método e rota | Perfil | RF/UC |
|---|---|---|
| `GET /api/me` | todos | RF01 / UC01 |
| `GET/POST/PUT /api/locais`, `PATCH /api/locais/{id}/ativo` | ADMIN | RF02 / UC02 |
| `GET/POST /api/locais/{id}/bloqueios`, `DELETE /api/locais/bloqueios/{id}` | ADMIN | RF02 / UC03 |
| `GET /api/locais/disponiveis?inicio&fim&capacidade` | ADMIN | RF03 / UC04 |
| `POST/PUT /api/eventos`, `POST /api/eventos/{id}/encerrar` | ADMIN | RF04 / UC05 |
| `GET /api/eventos`, `GET /api/eventos/{id}` | todos | RF05 / UC06 |
| `POST /api/eventos/{id}/inscricoes?fila=true\|false` | todos | RF06, RF07 / UC07, UC09 |
| `DELETE /api/inscricoes/{id}` | dono ou ADMIN | RF06 / UC08 (promove a fila: UC10) |
| `GET /api/inscricoes/minhas` | todos | RF08 / UC11 |
| `POST /api/eventos/{id}/checkin` | ADMIN | RF09 / UC12 |
| `POST/GET /api/inscricoes/{id}/certificado` | dono ou ADMIN | RF10 / UC13 |
| `GET /api/certificados/verificar/{codigo}` | ADMIN | RF10 / UC14 |
| `GET /api/painel`, `GET /api/eventos/{id}/inscritos`, `PATCH /api/eventos/{id}/vagas` | ADMIN | RF11 / UC15, UC16 |

## Testes feitos
O banco foi validado com 27 cenários em uma transação desfeita ao final (conflito de agenda, capacidade, bloqueios, lotação, fila FIFO, promoção ao cancelar, ajuste de vagas, check-in duplo/imutável/de outro evento, certificado sem presença, verificação de código, painel).
O front-end passa em `tsc --strict` e `vite build`.

---

---

## Implantação na AWS (Learner Lab)

Endereço público: **https://uvnnlhqp9h.execute-api.us-east-1.amazonaws.com/** (acesso pelo navegador, sem instalar nada).
Usuários de teste: `organizador` / `admin123` (ADMIN) e `aluno` / `aluno123` (PARTICIPANTE).

```
Navegador ──HTTPS──▶ API Gateway HTTP (us-east-1) ──HTTP──▶ EC2 t3.medium (IP elástico, Amazon Linux 2023)
                                                              └─ Docker Compose
                                                                  ├─ web       nginx: "/" → React (build), "/api/" → api, "/auth/" → keycloak
                                                                  ├─ api       Spring Boot (porta 8080)
                                                                  └─ keycloak  Keycloak 26 (start-dev, caminho /auth)
                                                              API ──JDBC (Session pooler, SSL)──▶ PostgreSQL no Supabase (sa-east-1)
```

Decisões:
- **HTTPS pelo API Gateway:** o `keycloak-js` (PKCE) exige contexto seguro e a CloudFront é bloqueada no Learner Lab. O API Gateway HTTP entrega o HTTPS e repassa tudo para o nginx da instância.
- **Mesmo endereço para tudo:** o nginx roteia `/` (SPA), `/api/*` (API) e `/auth/*` (Keycloak), então não há CORS entre origens e o `issuer` do token é `https://<endereço>/auth/realms/eventos`.
- **Banco:** Supabase PostgreSQL pelo *Session pooler* (`aws-0-sa-east-1.pooler.supabase.com:5432`, usuário `postgres.<ref>`), porque a EC2 só tem IPv4.
- **IP fixo:** um IP elástico fica associado à instância; a integração do API Gateway aponta para o DNS desse IP. O endereço público do site não muda quando o laboratório reinicia. Os contêineres usam `restart: unless-stopped`.

### Arquivos
| Arquivo | Função |
|---|---|
| `deploy/aws/user-data.sh` | Script de *user data* da EC2: instala Docker, clona o repositório, descobre o endereço do API Gateway e sobe o Compose |
| `deploy/aws/docker-compose.yml` | Serviços `keycloak`, `api` e `web` |
| `deploy/aws/Dockerfile.web` | Build do React e imagem do nginx |
| `deploy/aws/nginx.conf.template` | Roteamento `/`, `/api/`, `/auth/` e cabeçalhos `X-Forwarded-*` |

### Passo a passo
1. **Segurança:** security group com entrada TCP 80 aberta. Abra a porta 22 só temporariamente e só para o EC2 Instance Connect, se precisar de terminal.
2. **API Gateway:** crie uma *HTTP API* chamada `eventos` com rota `$default` e integração HTTP para `http://<DNS público da EC2>`.
3. **EC2:** Amazon Linux 2023, `t3.medium`, par de chaves do laboratório, *user data* = `deploy/aws/user-data.sh` com `DB_PASSWORD` e `KC_ADMIN_PASSWORD` preenchidos **apenas no console** (nunca no repositório).
4. **IP elástico:** aloque e associe à instância; atualize a URL da integração do API Gateway para `http://ec2-<ip-com-hifens>.compute-1.amazonaws.com`.
5. Aguarde o build (alguns minutos) e abra o endereço do API Gateway.

Para trocar a senha do banco depois: altere no Supabase (*Project Settings → Database*), edite `DB_PASSWORD` em `/opt/eventos/deploy/aws/.env` na instância e rode `sudo docker compose up -d --force-recreate api` dentro de `deploy/aws`.

### Aderência ao plano de implantação
| Exigência | Implementação |
|---|---|
| Front-end Vue ou React | React 18 + Vite + TypeScript |
| Back-end Java com Spring Boot | Spring Boot 3.3.5, Java 21 |
| Keycloak | Keycloak 26, realm `eventos` |
| PostgreSQL ou MariaDB | PostgreSQL 17 (Supabase) |

### Aderência ao diagrama do Moodle
O diagrama prevê três VMs na MackCloud (aplicações, banco e Keycloak), borda GERTI com SSL, BFF e API separados, MariaDB com dois bancos e Squid Proxy de saída. A implantação atual é uma versão simplificada em uma única instância:

| No diagrama | Nesta implantação |
|---|---|
| Borda externa com HTTPS e roteamento por URL | API Gateway da AWS |
| VM 1: nginx com `/` → SPA e `/api/*` → back-end | Igual, em contêiner na EC2 |
| SPA em Vue.js | React |
| BFF + API (dois contêineres Spring Boot) | Uma API Spring Boot |
| VM 3 própria para o Keycloak, com nginx e domínio `auth.…` | Keycloak na mesma instância, em `/auth` |
| VM 2 com MariaDB (bancos do Keycloak e do sistema) | PostgreSQL no Supabase (só o sistema); Keycloak com armazenamento interno |
| Squid Proxy de saída | Não utilizado |

### Limitações conhecidas
- O Keycloak roda em modo demonstração (`start-dev`) com armazenamento interno: usuários cadastrados pela tela de login se perdem se o contêiner for recriado. Os usuários de teste vêm do realm importado.
- O Learner Lab tem sessão temporária; o IP elástico e o API Gateway mantêm o endereço, mas não foi validado um ciclo completo de reinício do laboratório.
- Troque as senhas de demonstração (admin do Keycloak e usuários de teste) antes de qualquer uso real.
