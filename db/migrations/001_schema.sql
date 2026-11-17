-- 001_schema: tipos, tabelas, constraints e triggers de validacao
-- Sistema de Gestao de Eventos e Auditorios (PostgreSQL / Supabase)

create extension if not exists btree_gist with schema extensions;
set search_path = public, extensions;

create type perfil_usuario   as enum ('ADMIN', 'PARTICIPANTE');
create type estado_evento    as enum ('ABERTO', 'LOTADO', 'ENCERRADO', 'REALIZADO');
create type status_inscricao as enum ('CONFIRMADA', 'EM_ESPERA', 'CANCELADA');

-- Usuarios: identidade vem do Keycloak (claim "sub"); aqui ficam so os dados do dominio.
create table usuarios (
  id          uuid primary key default gen_random_uuid(),
  keycloak_id text not null unique,
  nome        text not null,
  email       text not null unique,
  ra          text,
  perfil      perfil_usuario not null default 'PARTICIPANTE',
  criado_em   timestamptz not null default now()
);

-- RF02 locais
create table locais (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null unique,
  capacidade  integer not null check (capacidade > 0),
  localizacao text not null,
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

-- RF02 bloqueios de agenda (sem sobreposicao no mesmo local)
create table bloqueios_local (
  id        uuid primary key default gen_random_uuid(),
  local_id  uuid not null references locais(id) on delete cascade,
  inicio    timestamptz not null,
  fim       timestamptz not null,
  motivo    text,
  criado_em timestamptz not null default now(),
  check (fim > inicio),
  exclude using gist (local_id with =, tstzrange(inicio, fim) with &&)
);

-- RF04 eventos e subeventos (um nivel)
create table eventos (
  id             uuid primary key default gen_random_uuid(),
  evento_pai_id  uuid references eventos(id) on delete cascade,
  titulo         text not null,
  descricao      text,
  local_id       uuid not null references locais(id),
  inicio         timestamptz not null,
  fim            timestamptz not null,
  vagas          integer not null check (vagas >= 0),
  estado         estado_evento not null default 'ABERTO',
  carga_horaria  numeric(5,2) not null default 1 check (carga_horaria > 0),
  criado_por     uuid references usuarios(id),
  criado_em      timestamptz not null default now(),
  check (fim > inicio),
  -- RN01/RN02: sem eventos principais conflitantes no mesmo local (a prova de concorrencia)
  constraint eventos_sem_conflito_principal
    exclude using gist (local_id with =, tstzrange(inicio, fim) with &&)
    where (evento_pai_id is null and estado in ('ABERTO', 'LOTADO')),
  constraint eventos_sem_conflito_sub
    exclude using gist (local_id with =, tstzrange(inicio, fim) with &&)
    where (evento_pai_id is not null and estado in ('ABERTO', 'LOTADO'))
);
create index eventos_local_idx on eventos(local_id);
create index eventos_pai_idx   on eventos(evento_pai_id);

-- RF06/RF07 inscricoes e fila de espera (ordem = ordem de entrada)
create table inscricoes (
  id             uuid primary key default gen_random_uuid(),
  evento_id      uuid not null references eventos(id) on delete cascade,
  usuario_id     uuid not null references usuarios(id) on delete cascade,
  status         status_inscricao not null,
  ordem          bigint generated always as identity,
  codigo_checkin uuid not null default gen_random_uuid() unique,
  criado_em      timestamptz not null default now(),
  promovida_em   timestamptz,
  cancelada_em   timestamptz
);
-- RN06: uma inscricao ativa por participante/evento (permite reinscrever apos cancelar)
create unique index inscricoes_unica_ativa on inscricoes(evento_id, usuario_id) where status <> 'CANCELADA';
create index inscricoes_fila_idx   on inscricoes(evento_id, status, ordem);
create index inscricoes_usuario_idx on inscricoes(usuario_id);

-- RF09 check-in: um por inscricao (RN08), imutavel (RNF07)
create table checkins (
  id            uuid primary key default gen_random_uuid(),
  inscricao_id  uuid not null unique references inscricoes(id),
  registrado_em timestamptz not null default now(),
  validado_por  uuid references usuarios(id)
);

-- RF10 certificados com codigo unico e nao previsivel (RN10, RNF08)
create table certificados (
  id                uuid primary key default gen_random_uuid(),
  inscricao_id      uuid not null unique references inscricoes(id),
  codigo_verificacao text not null unique
    default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  emitido_em        timestamptz not null default now(),
  carga_horaria     numeric(5,2) not null
);

-- Validacoes de eventos: local ativo, capacidade, subevento, conflito de agenda e bloqueios
create function trg_eventos_validar() returns trigger
language plpgsql set search_path = public as $$
declare
  v_local locais;
  v_pai   eventos;
begin
  select * into v_local from locais where id = new.local_id;
  if tg_op = 'INSERT' or new.local_id is distinct from old.local_id then
    if not v_local.ativo then raise exception 'LOCAL_INATIVO'; end if;
  end if;
  if new.vagas > v_local.capacidade then raise exception 'CAPACIDADE_EXCEDIDA'; end if;

  if new.evento_pai_id is not null then
    select * into v_pai from eventos where id = new.evento_pai_id;
    if not found or v_pai.evento_pai_id is not null then raise exception 'EVENTO_PAI_INVALIDO'; end if;
    if new.inicio < v_pai.inicio or new.fim > v_pai.fim then raise exception 'SUBEVENTO_FORA_DO_PERIODO'; end if;
  end if;

  if new.estado in ('ABERTO', 'LOTADO') then
    if exists (
      select 1 from eventos e
      where e.id <> new.id
        and e.local_id = new.local_id
        and e.estado in ('ABERTO', 'LOTADO')
        and tstzrange(e.inicio, e.fim) && tstzrange(new.inicio, new.fim)
        and e.id is distinct from new.evento_pai_id
        and e.evento_pai_id is distinct from new.id
    ) then raise exception 'CONFLITO_AGENDA'; end if;

    if exists (
      select 1 from bloqueios_local b
      where b.local_id = new.local_id
        and tstzrange(b.inicio, b.fim) && tstzrange(new.inicio, new.fim)
    ) then raise exception 'LOCAL_BLOQUEADO'; end if;
  end if;
  return new;
end $$;

create trigger eventos_validar before insert or update on eventos
for each row execute function trg_eventos_validar();

-- Bloqueio nao pode cobrir evento ja marcado
create function trg_bloqueios_validar() returns trigger
language plpgsql set search_path = public as $$
begin
  if exists (
    select 1 from eventos e
    where e.local_id = new.local_id
      and e.estado in ('ABERTO', 'LOTADO')
      and tstzrange(e.inicio, e.fim) && tstzrange(new.inicio, new.fim)
  ) then raise exception 'CONFLITO_COM_EVENTO'; end if;
  return new;
end $$;

create trigger bloqueios_validar before insert or update on bloqueios_local
for each row execute function trg_bloqueios_validar();

-- RNF07: check-in nao pode ser alterado nem apagado
create function trg_checkins_imutavel() returns trigger
language plpgsql set search_path = public as $$
begin
  raise exception 'CHECKIN_IMUTAVEL';
end $$;

create trigger checkins_imutavel before update or delete on checkins
for each row execute function trg_checkins_imutavel();
