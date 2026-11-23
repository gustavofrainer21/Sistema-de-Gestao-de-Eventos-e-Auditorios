# Especificação Atualizada — Sistema de Gestão de Eventos e Auditórios

Atualiza a especificação da Sprint 2 (`Sprint2_Documento_de_Especificacao.pdf`) com o que foi de fato implementado e implantado. Requisitos, casos de uso e diagramas originais permanecem em `Documentos do Projeto/` (Lista de Requisitos, Casos de Uso, Diagramas, Wireframes).

## 1. Visão geral
Sistema web para gerir locais (auditórios), eventos, inscrições com fila de espera, check-in, certificados e acompanhamento administrativo. Perfis: **Administrador/Organizador** e **Participante**.

## 2. Arquitetura implementada
| Camada | Tecnologia |
|---|---|
| Front-end | React 18 + Vite + TypeScript (SPA) |
| Back-end | Java 21, Spring Boot 3.3.5 (API REST, OAuth2 Resource Server / JWT) |
| Autenticação | Keycloak 26, realm `eventos`, Authorization Code + PKCE, papéis `ADMIN` e `PARTICIPANTE` |
| Banco | PostgreSQL 17 (Supabase) — regras de negócio em funções, gatilhos e restrições |
| Implantação | AWS Learner Lab: EC2 + Docker Compose (nginx, API, Keycloak); HTTPS por API Gateway; IP elástico |

Detalhes, endpoints e passo a passo: `docs/IMPLEMENTACAO.md`.

## 3. Situação dos requisitos
| Requisito | Situação | Onde está implementado | Teste |
|---|---|---|---|
| RF01 Acesso e perfis | Implementado | Keycloak + `SecurityConfig` + `@PreAuthorize` | TC-UI-01..03, 18 |
| RF02 Locais e bloqueios | Implementado | `locais`, `bloqueios` + restrição de exclusão | TC-DB-04, 07..10 |
| RF03 Disponibilidade de locais | Implementado | `GET /api/locais/disponiveis` | TC-UI-11 |
| RF04 Eventos e subeventos | Implementado | `fn_*` de evento, restrições, rotina de conclusão | TC-DB-01..06, 40..43 |
| RF05 Catálogo | Implementado | `GET /api/eventos` | TC-UI-04 |
| RF06 Inscrição e cancelamento | Implementado | `fn_inscrever`, `fn_cancelar_inscricao` | TC-DB-11..21 |
| RF07 Fila de espera (FIFO) | Implementado | `fn_promover_fila` | TC-DB-15, 18, 19, 24 |
| RF08 Área do participante | Implementado | `GET /api/inscricoes/minhas` | TC-UI-09 |
| RF09 Check-in | Implementado (código/QR individual; leitor de crachá não integrado) | `fn_registrar_checkin` | TC-DB-26..33 |
| RF10 Certificados | Implementado | `fn_emitir_certificado`, `fn_verificar_certificado` | TC-DB-34..39 |
| RF11 Acompanhamento administrativo | Implementado | `vw_painel_eventos`, ajuste de vagas | TC-DB-22..25, TC-UI-17 |

## 4. Regras de negócio
RN01/RN02 (sem conflito de agenda no mesmo local), RN03 (capacidade/vagas), RN04 (lotado → fila), RN05 (ordem FIFO), RN06 (sem inscrição duplicada), RN07 (check-in só de inscrito confirmado do evento), RN08 (check-in único), RN09 (certificado só com presença e evento concluído), RN10 (código único de verificação de 64 caracteres). Todas aplicadas no banco, portanto valem para qualquer cliente da API.

## 5. Requisitos não funcionais atendidos
- **Segurança:** autenticação obrigatória, autorização por perfil, banco inacessível pela API pública do Supabase (RLS), registros de check-in imutáveis. Ver `Relatorio_PenTest.md`.
- **Integridade:** restrições de exclusão e gatilhos no banco.
- **Implantação reproduzível:** `docker-compose.yml` e `deploy/aws/`.

## 6. Mudanças em relação à especificação da Sprint 2
1. Regras de negócio concentradas no PostgreSQL (e não na camada Java), para garantir consistência sob concorrência.
2. Keycloak adotado para autenticação (login, papéis), conforme o plano de implantação.
3. Hospedagem na AWS Learner Lab em vez de Render/Vercel.
4. Sem leitor de chip de crachá: o check-in usa código/QR.

## 7. Desvios conhecidos em relação ao diagrama da MackCloud
Uma única instância em vez de três VMs; sem BFF separado da API; Keycloak sem banco próprio (armazenamento interno); sem Squid. Tabela completa em `docs/IMPLEMENTACAO.md`. A adequação fica como evolução.
