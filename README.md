# Sistema de Gestão de Eventos e Auditórios

<h2>Nomes dos Integrantes</h2>
<p>André Drumond</p>
<p>Eduardo Bighetti</p>
<p>Gabriel Magdaleno</p>
<p>Gustavo Frainer</p>

<br>

<h2>Objetivos do Projeto</h2>

• Reduzir o esforço operacional necessário para organizar eventos acadêmicos. <br>
• Evitar conflitos de uso de auditórios e apoiar a escolha de espaços compatíveis com a quantidade
esperada de participantes. <br>
• Controlar automaticamente a quantidade de vagas disponíveis e o tratamento de eventos lotados. <br>
• Dar ao participante uma visão clara de suas inscrições e de sua situação em cada evento. <br>
• Registrar a presença dos participantes de forma rápida e auditável. <br>
• Automatizar a emissão de certificados para participantes que efetivamente compareceram ao
evento. <br>
• Permitir que organizadores acompanhem informações básicas sobre eventos, inscrições, presença e
certificação. <br>

<br>

<h2>Implementação e Implantação</h2>

O sistema está implementado e publicado na AWS (Learner Lab):

• **Acesso:** https://uvnnlhqp9h.execute-api.us-east-1.amazonaws.com/ (usuários de teste: `organizador` / `admin123` e `aluno` / `aluno123`). <br>
• **Stack:** React (Vite + TypeScript), Java 21 + Spring Boot 3.3, Keycloak 26 e PostgreSQL (Supabase). <br>
• **Código:** `frontend/`, `backend/`, `keycloak/`, `db/` (migrations) e `deploy/aws/` (implantação). <br>
• **Documentação técnica:** [docs/IMPLEMENTACAO.md](docs/IMPLEMENTACAO.md) (arquitetura, execução local, endpoints, regras de negócio, implantação na AWS e comparação com o diagrama do Moodle). <br>

## Documentação final
Em `Documentos do Projeto/Documentacao Final/`: [Especificação Atualizada](<Documentos do Projeto/Documentacao Final/Especificacao_Atualizada.md>), [Plano de Teste e Evidências](<Documentos do Projeto/Documentacao Final/Plano_de_Teste.md>), [Relatório de Pen Test](<Documentos do Projeto/Documentacao Final/Relatorio_PenTest.md>) e [Relato do Vibe Code](<Documentos do Projeto/Documentacao Final/Relato_Vibe_Code.md>). Testes automatizados do banco: `db/testes/testes_regras.sql`.
