-- 003_seguranca: o banco so e acessado pelo back-end (Spring Boot) com a role do servidor.
-- A API REST publica do Supabase (anon/authenticated) nao pode ler nem escrever nada.

alter table usuarios        enable row level security;
alter table locais          enable row level security;
alter table bloqueios_local enable row level security;
alter table eventos         enable row level security;
alter table inscricoes      enable row level security;
alter table checkins        enable row level security;
alter table certificados    enable row level security;

revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from public, anon, authenticated;
