-- 002_funcoes: regras de negocio (RN03-RN10) como funcoes transacionais.
-- Erros sao lancados como mensagens-codigo (ex.: EVENTO_LOTADO) que o back-end traduz para HTTP.

create function fn_sincronizar_estado_evento(p_evento uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_ev eventos;
  v_conf integer;
  v_novo estado_evento;
begin
  select * into v_ev from eventos where id = p_evento;
  if not found or v_ev.estado in ('ENCERRADO', 'REALIZADO') then return; end if;
  select count(*) into v_conf from inscricoes where evento_id = p_evento and status = 'CONFIRMADA';
  v_novo := case when v_conf >= v_ev.vagas then 'LOTADO' else 'ABERTO' end;
  if v_novo <> v_ev.estado then
    update eventos set estado = v_novo where id = p_evento;
  end if;
end $$;

-- RF07: promove da fila, em ordem de entrada, enquanto houver vaga
create function fn_promover_fila(p_evento uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_ev eventos;
  v_conf integer;
  v_prox uuid;
  v_prom integer := 0;
begin
  select * into v_ev from eventos where id = p_evento for update;
  if not found or v_ev.estado in ('ENCERRADO', 'REALIZADO') then return 0; end if;
  loop
    select count(*) into v_conf from inscricoes where evento_id = p_evento and status = 'CONFIRMADA';
    exit when v_conf >= v_ev.vagas;
    select id into v_prox from inscricoes
      where evento_id = p_evento and status = 'EM_ESPERA' order by ordem limit 1;
    exit when v_prox is null;
    update inscricoes set status = 'CONFIRMADA', promovida_em = now() where id = v_prox;
    v_prom := v_prom + 1;
  end loop;
  perform fn_sincronizar_estado_evento(p_evento);
  return v_prom;
end $$;

-- RF06/RF07: inscreve (RN03), bloqueia duplicidade (RN06) e envia para a fila se lotado (RN04/RN05)
create function fn_inscrever(p_evento uuid, p_usuario uuid, p_entrar_fila boolean default false)
returns inscricoes
language plpgsql security definer set search_path = public as $$
declare
  v_ev eventos;
  v_conf integer;
  v_row inscricoes;
begin
  select * into v_ev from eventos where id = p_evento for update;
  if not found then raise exception 'EVENTO_NAO_ENCONTRADO'; end if;
  if v_ev.estado in ('ENCERRADO', 'REALIZADO') or v_ev.fim <= now() then
    raise exception 'EVENTO_FECHADO';
  end if;
  if exists (select 1 from inscricoes
             where evento_id = p_evento and usuario_id = p_usuario and status <> 'CANCELADA') then
    raise exception 'INSCRICAO_DUPLICADA';
  end if;

  select count(*) into v_conf from inscricoes where evento_id = p_evento and status = 'CONFIRMADA';
  if v_conf < v_ev.vagas then
    insert into inscricoes(evento_id, usuario_id, status)
    values (p_evento, p_usuario, 'CONFIRMADA') returning * into v_row;
  elsif p_entrar_fila then
    insert into inscricoes(evento_id, usuario_id, status)
    values (p_evento, p_usuario, 'EM_ESPERA') returning * into v_row;
  else
    raise exception 'EVENTO_LOTADO';
  end if;
  perform fn_sincronizar_estado_evento(p_evento);
  return v_row;
end $$;

-- RF06: cancela; se liberou vaga, promove o proximo da fila. p_usuario null = administrador.
create function fn_cancelar_inscricao(p_inscricao uuid, p_usuario uuid default null)
returns inscricoes
language plpgsql security definer set search_path = public as $$
declare
  v_insc inscricoes;
  v_ev eventos;
  v_era inscricoes;
begin
  select evento_id into v_insc.evento_id from inscricoes where id = p_inscricao;
  if not found then raise exception 'INSCRICAO_NAO_ENCONTRADA'; end if;
  select * into v_ev from eventos where id = v_insc.evento_id for update;
  select * into v_insc from inscricoes where id = p_inscricao for update;

  if p_usuario is not null and v_insc.usuario_id <> p_usuario then raise exception 'SEM_PERMISSAO'; end if;
  if v_insc.status = 'CANCELADA' then raise exception 'INSCRICAO_JA_CANCELADA'; end if;
  if v_ev.estado in ('ENCERRADO', 'REALIZADO') then raise exception 'EVENTO_FECHADO'; end if;
  if exists (select 1 from checkins where inscricao_id = p_inscricao) then
    raise exception 'CHECKIN_JA_REGISTRADO';
  end if;

  v_era := v_insc;
  update inscricoes set status = 'CANCELADA', cancelada_em = now()
   where id = p_inscricao returning * into v_insc;

  if v_era.status = 'CONFIRMADA' then
    perform fn_promover_fila(v_insc.evento_id);
  else
    perform fn_sincronizar_estado_evento(v_insc.evento_id);
  end if;
  return v_insc;
end $$;

-- RF11: ajuste de vagas pelo administrador (capacidade validada pelo trigger do evento)
create function fn_ajustar_vagas(p_evento uuid, p_vagas integer) returns eventos
language plpgsql security definer set search_path = public as $$
declare
  v_ev eventos;
  v_conf integer;
begin
  select * into v_ev from eventos where id = p_evento for update;
  if not found then raise exception 'EVENTO_NAO_ENCONTRADO'; end if;
  if v_ev.estado in ('ENCERRADO', 'REALIZADO') then raise exception 'EVENTO_FECHADO'; end if;
  select count(*) into v_conf from inscricoes where evento_id = p_evento and status = 'CONFIRMADA';
  if p_vagas < v_conf then raise exception 'VAGAS_MENORES_QUE_CONFIRMADOS'; end if;
  update eventos set vagas = p_vagas where id = p_evento;
  perform fn_promover_fila(p_evento);
  select * into v_ev from eventos where id = p_evento;
  return v_ev;
end $$;

-- RF09: check-in so de inscrito confirmado do proprio evento (RN07), uma unica vez (RN08)
create function fn_registrar_checkin(p_codigo uuid, p_evento uuid, p_validador uuid)
returns checkins
language plpgsql security definer set search_path = public as $$
declare
  v_insc inscricoes;
  v_ev eventos;
  v_row checkins;
begin
  select * into v_insc from inscricoes where codigo_checkin = p_codigo for update;
  if not found then raise exception 'CODIGO_INVALIDO'; end if;
  if v_insc.evento_id <> p_evento then raise exception 'INSCRICAO_OUTRO_EVENTO'; end if;
  if v_insc.status <> 'CONFIRMADA' then raise exception 'INSCRICAO_NAO_CONFIRMADA'; end if;
  select * into v_ev from eventos where id = p_evento;
  if v_ev.estado = 'ENCERRADO' then raise exception 'EVENTO_FECHADO'; end if;
  if exists (select 1 from checkins where inscricao_id = v_insc.id) then
    raise exception 'CHECKIN_JA_REGISTRADO';
  end if;
  insert into checkins(inscricao_id, validado_por) values (v_insc.id, p_validador) returning * into v_row;
  return v_row;
end $$;

-- RF10: certificado so para quem teve presenca (RN09); idempotente
create function fn_emitir_certificado(p_inscricao uuid, p_usuario uuid default null)
returns certificados
language plpgsql security definer set search_path = public as $$
declare
  v_insc inscricoes;
  v_ev eventos;
  v_cert certificados;
begin
  select * into v_insc from inscricoes where id = p_inscricao;
  if not found then raise exception 'INSCRICAO_NAO_ENCONTRADA'; end if;
  if p_usuario is not null and v_insc.usuario_id <> p_usuario then raise exception 'SEM_PERMISSAO'; end if;
  if not exists (select 1 from checkins where inscricao_id = p_inscricao) then
    raise exception 'SEM_PRESENCA';
  end if;
  select * into v_ev from eventos where id = v_insc.evento_id;
  if not (v_ev.estado = 'REALIZADO' or v_ev.fim <= now()) then raise exception 'EVENTO_NAO_CONCLUIDO'; end if;

  insert into certificados(inscricao_id, carga_horaria)
  values (p_inscricao, v_ev.carga_horaria)
  on conflict (inscricao_id) do nothing;
  select * into v_cert from certificados where inscricao_id = p_inscricao;
  return v_cert;
end $$;

-- RF10: verificacao publica pelo codigo (nenhuma linha = invalido)
create function fn_verificar_certificado(p_codigo text)
returns table (participante text, evento text, data_evento timestamptz, carga_horaria numeric, emitido_em timestamptz)
language sql security definer set search_path = public stable as $$
  select u.nome, e.titulo, e.inicio, c.carga_horaria, c.emitido_em
  from certificados c
  join inscricoes i on i.id = c.inscricao_id
  join usuarios u on u.id = i.usuario_id
  join eventos e on e.id = i.evento_id
  where c.codigo_verificacao = lower(trim(p_codigo));
$$;

-- Rotina agendada pelo back-end: eventos cujo horario terminou passam a REALIZADO
create function fn_concluir_eventos_finalizados() returns integer
language plpgsql security definer set search_path = public as $$
declare v_n integer;
begin
  update eventos set estado = 'REALIZADO'
   where estado in ('ABERTO', 'LOTADO') and fim <= now();
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- RF11: painel com contagens operacionais
create view vw_painel_eventos with (security_invoker = true) as
select e.id as evento_id,
       e.titulo,
       e.estado,
       e.vagas,
       count(i.id) filter (where i.status = 'CONFIRMADA') as confirmados,
       count(i.id) filter (where i.status = 'EM_ESPERA')  as em_espera,
       count(c.id)  as presencas,
       count(ce.id) as certificados
from eventos e
left join inscricoes i   on i.evento_id = e.id
left join checkins c     on c.inscricao_id = i.id
left join certificados ce on ce.inscricao_id = i.id
group by e.id;
