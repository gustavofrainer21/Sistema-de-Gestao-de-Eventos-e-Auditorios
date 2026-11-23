# Plano de Teste e Evidências de Casos de Teste

Sistema de Gestão de Eventos e Auditórios — Universidade Presbiteriana Mackenzie

## 1. Estratégia de teste

As regras de negócio (RN01–RN10) estão implementadas no PostgreSQL (funções, gatilhos e restrições de exclusão). Por isso a camada principal de teste executa as regras diretamente no banco, de forma automatizada, e repete-se pela interface web (testes de aceitação) com a aplicação rodando na AWS.

| Nível | Objetivo | Como é executado | Evidência |
|---|---|---|---|
| Regras no banco (TC-DB) | Validar RN01–RN10, RF02, RF04, RF06, RF07, RF10, RF11, RNF06, RNF07 | Script `db/testes/testes_regras.sql`, executado no Supabase. Termina com `raise exception`, então **todos os dados criados são desfeitos** (nada fica no banco) | Resultado JSON da execução (seção 3) |
| Aceitação pela interface (TC-UI) | Validar os fluxos do participante e do administrador na aplicação em produção (AWS) | Execução manual guiada, com captura de tela | Pasta `Documentos do Projeto/Documentacao Final/evidencias/` |
| Segurança | Verificar autenticação, autorização e configuração | Revisão estática + verificações black-box (ver `Relatorio_PenTest.md`) | Relatório de Pen Test |

## 2. Ambiente

- Aplicação: AWS (EC2 + Docker Compose; HTTPS via API Gateway); banco PostgreSQL no Supabase; autenticação Keycloak 26.
- Usuários de teste (perfis): participante e administrador (as senhas ficam no arquivo de configuração do ambiente, não neste repositório).
- Data da execução automatizada: 23/11/2026.

## 3. Casos de teste automatizados no banco (TC-DB)

Resultado da execução em 23/11/2026: **46 casos executados, 46 aprovados, 0 reprovados**. Não restaram dados no banco após a execução.

| ID | Requisito | Caso de teste | Resultado esperado | Resultado |
|---|---|---|---|---|
| TC-DB-01 | RF04 | Criar evento valido | `ok` | Aprovado |
| TC-DB-02 | RN01/RN02 | Evento no mesmo local e horario sobreposto | `ERRO:CONFLITO_AGENDA` | Aprovado |
| TC-DB-03 | RN03 | Vagas maiores que a capacidade do local | `ERRO:CAPACIDADE_EXCEDIDA` | Aprovado |
| TC-DB-04 | RF02 | Evento em local inativo | `ERRO:LOCAL_INATIVO` | Aprovado |
| TC-DB-05 | RF04 | Subevento dentro do periodo do evento principal | `ok` | Aprovado |
| TC-DB-06 | RF04 | Subevento fora do periodo do principal | `ERRO:SUBEVENTO_FORA_DO_PERIODO` | Aprovado |
| TC-DB-07 | RF02 | Criar bloqueio de agenda do local | `ok` | Aprovado |
| TC-DB-08 | RF02 | Evento dentro de periodo bloqueado | `ERRO:LOCAL_BLOQUEADO` | Aprovado |
| TC-DB-09 | RF02 | Bloqueio sobre evento ja marcado | `ERRO:CONFLITO_COM_EVENTO` | Aprovado |
| TC-DB-10 | RF02 | Bloqueios sobrepostos no mesmo local | `ERRO:conflicting key value violates exclusion constraint` | Aprovado |
| TC-DB-11 | RN03 | Inscricao com vaga disponivel | `CONFIRMADA` | Aprovado |
| TC-DB-12 | RN06 | Inscricao duplicada no mesmo evento | `ERRO:INSCRICAO_DUPLICADA` | Aprovado |
| TC-DB-13 | RN04 | Evento passa a LOTADO ao preencher as vagas | `LOTADO` | Aprovado |
| TC-DB-14 | RN04 | Inscricao em evento lotado sem entrar na fila | `ERRO:EVENTO_LOTADO` | Aprovado |
| TC-DB-15 | RN04 | Entrar na fila de espera com evento lotado | `EM_ESPERA` | Aprovado |
| TC-DB-16 | RN07 | Cancelar inscricao de outro participante | `ERRO:SEM_PERMISSAO` | Aprovado |
| TC-DB-17 | RF06 | Cancelar a propria inscricao | `CANCELADA` | Aprovado |
| TC-DB-18 | RN05 | Cancelamento promove o primeiro da fila (FIFO) | `CONFIRMADA` | Aprovado |
| TC-DB-19 | RN05 | Segundo da fila continua em espera | `EM_ESPERA` | Aprovado |
| TC-DB-20 | RF06 | Cancelar inscricao ja cancelada | `ERRO:INSCRICAO_JA_CANCELADA` | Aprovado |
| TC-DB-21 | RN06 | Reinscricao apos cancelamento (entra na fila) | `EM_ESPERA` | Aprovado |
| TC-DB-22 | RF11 | Reduzir vagas abaixo dos confirmados | `ERRO:VAGAS_MENORES_QUE_CONFIRMADOS` | Aprovado |
| TC-DB-23 | RF11 | Aumentar vagas (limite da capacidade) | `3` | Aprovado |
| TC-DB-24 | RF07 | Aumento de vagas promove proximo da fila | `CONFIRMADA` | Aprovado |
| TC-DB-25 | RN03 | Ajustar vagas acima da capacidade do local | `ERRO:CAPACIDADE_EXCEDIDA` | Aprovado |
| TC-DB-26 | RN07 | Check-in de inscrito confirmado | `ok` | Aprovado |
| TC-DB-27 | RN08 | Segundo check-in da mesma inscricao | `ERRO:CHECKIN_JA_REGISTRADO` | Aprovado |
| TC-DB-28 | RN07 | Check-in com codigo de outro evento | `ERRO:INSCRICAO_OUTRO_EVENTO` | Aprovado |
| TC-DB-29 | RN07 | Check-in de inscricao em espera | `ERRO:INSCRICAO_NAO_CONFIRMADA` | Aprovado |
| TC-DB-30 | RN07 | Check-in com codigo inexistente | `ERRO:CODIGO_INVALIDO` | Aprovado |
| TC-DB-31 | RNF07 | Alterar um check-in ja registrado | `ERRO:CHECKIN_IMUTAVEL` | Aprovado |
| TC-DB-32 | RNF07 | Apagar um check-in ja registrado | `ERRO:CHECKIN_IMUTAVEL` | Aprovado |
| TC-DB-33 | RF06 | Cancelar inscricao que ja tem presenca | `ERRO:CHECKIN_JA_REGISTRADO` | Aprovado |
| TC-DB-34 | RN09 | Certificado sem presenca registrada | `ERRO:SEM_PRESENCA` | Aprovado |
| TC-DB-35 | RN09 | Certificado de evento que ainda nao terminou | `ERRO:EVENTO_NAO_CONCLUIDO` | Aprovado |
| TC-DB-36 | RN09/RN10 | Certificado emitido com presenca (codigo de 64 caracteres) | `64` | Aprovado |
| TC-DB-37 | RN10 | Emitir de novo nao duplica o certificado | `1` | Aprovado |
| TC-DB-38 | RF10 | Verificar certificado valido | `Participante Um` | Aprovado |
| TC-DB-39 | RF10 | Verificar certificado inexistente | `0` | Aprovado |
| TC-DB-40 | RF04 | Rotina marca eventos terminados como REALIZADO | `true` | Aprovado |
| TC-DB-41 | RF04 | Estado do evento passado apos a rotina | `REALIZADO` | Aprovado |
| TC-DB-42 | RF04 | Inscricao em evento encerrado | `ERRO:EVENTO_FECHADO` | Aprovado |
| TC-DB-43 | RF06 | Inscricao em evento que ja terminou | `ERRO:EVENTO_FECHADO` | Aprovado |
| TC-DB-44 | RNF06 | Leitura de eventos pela role publica anon (API REST do Supabase) | `ERRO:permission denied` | Aprovado |
| TC-DB-45 | RNF06 | Execucao de funcao de regra pela role anon | `ERRO:permission denied` | Aprovado |
| TC-DB-46 | RNF06 | Tabelas do schema public sem RLS ligado | `0` | Aprovado |

Para reexecutar: abrir o SQL Editor do Supabase (ou `psql`), colar o conteúdo de `db/testes/testes_regras.sql` e executar. O resultado aparece na mensagem de erro `RESULTADO [...]` (a exceção é proposital para desfazer os dados).

## 4. Casos de aceitação pela interface (TC-UI)

Execução em 23/11/2026 na aplicação em produção (AWS), com os usuários `aluno` e `organizador`. 15 dos 18 casos foram executados e aprovados; TC-UI-04, 10 e 11 permanecem pendentes. A coluna Evidência aponta a captura de tela que será anexada em `evidencias/`.

| ID | Requisito | Caso de teste | Resultado esperado | Status | Evidência |
|---|---|---|---|---|---|
| TC-UI-01 | RF01 | Acessar o sistema sem login | Redireciona para a tela de login do Keycloak | Aprovado (23/11/2026; sem token, o site abre o login do Keycloak) | (captura a anexar) |
| TC-UI-02 | RF01 | Login como participante | Entra no catálogo; não vê o menu administrativo | Aprovado (23/11/2026; usuário `aluno` vê só Catálogo e Minhas inscrições) | evidencias/TC-UI-02.jpg |
| TC-UI-03 | RF01 | Login como administrador | Vê o painel e as telas administrativas | Aprovado (23/11/2026; `organizador` vê Painel, Locais, Novo evento e Verificar certificado) | (sem captura) |
| TC-UI-04 | RF05 | Consultar catálogo e detalhes de evento | Lista data, horário, local e vagas; mostra subeventos | Pendente | evidencias/TC-UI-04.png |
| TC-UI-05 | RF06 | Inscrever-se em evento com vaga | Inscrição CONFIRMADA | Aprovado (23/11/2026; "Inscrição confirmada!"; com 1 vaga o evento passa a Lotado) | evidencias/TC-UI-05.jpg |
| TC-UI-06 | RN06 | Inscrever-se duas vezes no mesmo evento | Mensagem de inscrição duplicada | Aprovado (23/11/2026; "Você já está inscrito neste evento.") | evidencias/TC-UI-06.jpg |
| TC-UI-07 | RF07 | Inscrever-se em evento lotado (fila) | Situação EM ESPERA com posição na fila | Aprovado (23/11/2026; "Você entrou na fila de espera."; contador mostra 1 na fila) | evidencias/TC-UI-07.jpg |
| TC-UI-08 | RN05 | Cancelar inscrição e verificar promoção da fila | Primeiro da fila vira CONFIRMADO | Aprovado (23/11/2026; após o cancelamento, Bruno Aluno aparece Confirmada, 1/1 confirmados e 0 na fila) | evidencias/TC-UI-08.jpg |
| TC-UI-09 | RF08 | Área do participante | Lista inscrições com situação e QR/código de check-in | Aprovado (23/11/2026; mostra situação Cancelada/Confirmada e QR Code de check-in) | evidencias/TC-UI-09.jpg |
| TC-UI-10 | RF02 | Administrador cadastra, edita e desativa local | Local salvo; desativado não aceita eventos | Pendente | evidencias/TC-UI-10.png |
| TC-UI-11 | RF03 | Consultar locais disponíveis por data/horário/capacidade | Só locais compatíveis são exibidos | Pendente | evidencias/TC-UI-11.png |
| TC-UI-12 | RN01/RN02 | Criar evento em conflito de agenda | Mensagem de conflito de agenda | Aprovado (23/11/2026; mensagem "Já existe um evento neste local e horário.") | evidencias/TC-UI-12.jpg |
| TC-UI-13 | RF09 | Administrador faz check-in com código válido | Presença registrada com horário | Aprovado (23/11/2026; "Check-in ACEITO" com horário; coluna Presença marcada) | evidencias/TC-UI-13.jpg |
| TC-UI-14 | RN08 | Repetir o check-in com o mesmo código | Rejeitado | Aprovado (23/11/2026; "Check-in REJEITADO: Check-in já registrado para esta inscrição.") | evidencias/TC-UI-14.jpg |
| TC-UI-15 | RF10 | Participante emite certificado após o evento | Certificado com código de verificação | Aprovado (23/11/2026; certificado emitido após o fim do evento, com código de 64 caracteres) | evidencias/TC-UI-15.jpg |
| TC-UI-16 | RF10 | Verificar certificado pelo código | Mostra participante e evento; código inválido é recusado | Aprovado (23/11/2026; código válido mostra participante e evento; código inválido: "Certificado não encontrado ou inválido.") | evidencias/TC-UI-16a-valido.jpg, evidencias/TC-UI-16b-invalido.jpg |
| TC-UI-17 | RF11 | Painel administrativo | Mostra vagas, inscritos, espera, presenças e certificados | Aprovado (23/11/2026; painel mostra estado, vagas, inscritos, em espera, presenças e certificados por evento) | evidencias/TC-UI-17.jpg |
| TC-UI-18 | RF01 | Participante tenta abrir tela/endpoint de administrador | Acesso negado (403) | Aprovado na interface (23/11/2026; `/admin` redireciona o aluno ao catálogo). Falta confirmar o 403 da API | evidencias/TC-UI-18.jpg |
