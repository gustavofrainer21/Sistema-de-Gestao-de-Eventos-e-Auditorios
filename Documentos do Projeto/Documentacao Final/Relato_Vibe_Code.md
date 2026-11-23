# Relato sobre as Estratégias Utilizadas no Vibe Code

> **Rascunho** feito a partir do que foi realizado com a IA (Claude). Cada integrante deve acrescentar, na seção 6, sua experiência pessoal (os relatos individuais por semana ficam em `Relatos-Individuais-IA/`).

## 1. Abordagem geral
O sistema foi construído conversando com a IA em passos curtos e verificáveis: primeiro o modelo de dados e as regras, depois a API, o front-end e, por último, a implantação. A IA escreveu e executou o código; a equipe definiu o que construir, decidiu e validou os resultados.

## 2. Estratégias que funcionaram
1. **Partir da documentação do grupo.** Requisitos (RF01–RF11), regras (RN01–RN10) e casos de uso foram dados à IA como contexto; o código mantém os mesmos identificadores (RF/RN/UC), o que facilita a rastreabilidade.
2. **Regras de negócio no banco.** Colocar as regras em funções, gatilhos e restrições do PostgreSQL deixou o comportamento verificável por SQL, sem depender da interface.
3. **Teste automatizado antes de confiar.** Criamos 46 casos (`db/testes/testes_regras.sql`) que rodam em transação desfeita. Os testes acharam erros do próprio script de teste e confirmaram que nada fica no banco.
4. **Verificar no ambiente real.** A IA testou o site publicado (login, API, banco) e não só o código local.
5. **Pedidos pequenos e iterativos.** Um problema por vez (senha do banco, host do pooler, banco pausado), com diagnóstico a partir de logs reais.
6. **Segurança desde o início.** Segredos fora do repositório (placeholders), RLS no banco, perfis no Keycloak, revisão estática para o Pen Test.
7. **Documentar enquanto constrói.** `docs/IMPLEMENTACAO.md` foi atualizado junto com o código.

## 3. Dificuldades e como foram resolvidas
| Problema | Causa | Solução |
|---|---|---|
| Falha de autenticação no banco | Senha diferente entre `.env` e Supabase | Redefinir a senha e atualizar o `.env` |
| Host do pooler errado | Região usa `aws-0`, não `aws-1` | Corrigir a partir da tela *Connect* do Supabase |
| "Database is possibly not accessible" | Projeto pausado por inatividade | Restaurar o projeto no Supabase |
| Site "Service Unavailable" | Learner Lab encerrado | Ligar o laboratório; IP elástico e API Gateway mantêm o endereço |
| Endereço mudava a cada reinício | IP público dinâmico | Elastic IP + API Gateway com URL HTTPS fixa |
| Falhas em 4 casos de teste | Erro no script (faltava `RETURNING`) | Corrigir o teste; 46/46 passam |
| Push ao GitHub do grupo negado | Aplicativo sem acesso ao repositório | Envio manual por upload |

## 4. Riscos e limites observados no uso de IA
- A IA pode gerar configurações inseguras por padrão (ex.: Keycloak em modo desenvolvimento); por isso fizemos revisão e Pen Test.
- Todo resultado importante foi conferido executando (testes, logs, site), não apenas lendo a resposta.
- Senhas e chaves nunca devem ir ao repositório nem ao chat.

## 5. Lições aprendidas
Dar contexto claro e rastreável, exigir testes, validar no ambiente real e registrar decisões. A IA acelera, mas a responsabilidade pelas decisões e pela segurança continua da equipe.

## 6. Experiência individual (preencher)
- André Drumond: _…_
- Eduardo Bighetti: _…_
- Gabriel Magdaleno: _…_
- Gustavo Frainer: _…_
