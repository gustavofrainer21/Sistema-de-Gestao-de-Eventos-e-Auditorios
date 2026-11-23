-- Testes automatizados das regras de negocio (RN01-RN10, RNF04/06/07/08) no PostgreSQL.
-- Executa tudo dentro de um unico bloco DO e termina com RAISE EXCEPTION, o que DESFAZ todos os dados de teste.
-- O resultado (JSON) vem na mensagem de erro final: "RESULTADO [...]".

create or replace function pg_temp.q(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  execute p_sql into v;
  return coalesce(v, 'NULL');
exception when others then
  return 'ERRO:' || sqlerrm;
end $f$;

create or replace function pg_temp.q_anon(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  set local role anon;
  execute p_sql into v;
  reset role;
  return coalesce(v, 'NULL');
exception when others then
  reset role;
  return 'ERRO:' || sqlerrm;
end $f$;

do $teste$
declare
  v_res jsonb := '[]'::jsonb;
  l1 uuid; l2 uuid; l3 uuid;
  u1 uuid; u2 uuid; u3 uuid; u4 uuid; adm uuid;
  e1 uuid; e2 uuid; e3 uuid; e4 uuid;
  i1 uuid; i2 uuid; i3 uuid; i4 uuid; i5 uuid; i_old uuid; i_old2 uuid;
  cod2 uuid; cod3 uuid; cod_old uuid;
  r text;
  v_cert text;

begin
  -- ===== massa de teste =====
  insert into locais(nome, capacidade, localizacao) values ('TESTE Auditorio', 10, 'teste') returning id into l1;
  insert into locais(nome, capacidade, localizacao) values ('TESTE Sala', 3, 'teste') returning id into l2;
  insert into locais(nome, capacidade, localizacao, ativo) values ('TESTE Inativo', 5, 'teste', false) returning id into l3;
  insert into usuarios(keycloak_id, nome, email) values ('t-1','Participante Um','t1@teste.local') returning id into u1;
  insert into usuarios(keycloak_id, nome, email) values ('t-2','Participante Dois','t2@teste.local') returning id into u2;
  insert into usuarios(keycloak_id, nome, email) values ('t-3','Participante Tres','t3@teste.local') returning id into u3;
  insert into usuarios(keycloak_id, nome, email) values ('t-4','Participante Quatro','t4@teste.local') returning id into u4;
  insert into usuarios(keycloak_id, nome, email, perfil) values ('t-adm','Organizador Teste','adm@teste.local','ADMIN') returning id into adm;

  -- ===== eventos / locais =====
  r := pg_temp.q(format($s$insert into eventos(titulo,local_id,inicio,fim,vagas) values ('E1',%L,'2027-03-01 10:00-03','2027-03-01 12:00-03',5) returning id::text$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-01','req','RF04','caso','Criar evento valido','esperado','ok','obtido', case when r like 'ERRO:%' then r else 'ok' end);
  select id into e1 from eventos where titulo='E1' and local_id=l1;

  r := pg_temp.q(format($s$insert into eventos(titulo,local_id,inicio,fim,vagas) values ('Conflito',%L,'2027-03-01 11:00-03','2027-03-01 13:00-03',5)$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-02','req','RN01/RN02','caso','Evento no mesmo local e horario sobreposto','esperado','ERRO:CONFLITO_AGENDA','obtido', r);

  r := pg_temp.q(format($s$insert into eventos(titulo,local_id,inicio,fim,vagas) values ('Grande',%L,'2027-03-02 10:00-03','2027-03-02 12:00-03',11)$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-03','req','RN03','caso','Vagas maiores que a capacidade do local','esperado','ERRO:CAPACIDADE_EXCEDIDA','obtido', r);

  r := pg_temp.q(format($s$insert into eventos(titulo,local_id,inicio,fim,vagas) values ('Inativo',%L,'2027-03-02 10:00-03','2027-03-02 12:00-03',2)$s$, l3));
  v_res := v_res || jsonb_build_object('id','TC-DB-04','req','RF02','caso','Evento em local inativo','esperado','ERRO:LOCAL_INATIVO','obtido', r);

  r := pg_temp.q(format($s$insert into eventos(evento_pai_id,titulo,local_id,inicio,fim,vagas) values (%L,'Sub ok',%L,'2027-03-01 10:30-03','2027-03-01 11:00-03',3) returning id::text$s$, e1, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-05','req','RF04','caso','Subevento dentro do periodo do evento principal','esperado','ok','obtido', case when r like 'ERRO:%' then r else 'ok' end);

  r := pg_temp.q(format($s$insert into eventos(evento_pai_id,titulo,local_id,inicio,fim,vagas) values (%L,'Sub fora',%L,'2027-03-01 11:30-03','2027-03-01 13:00-03',3)$s$, e1, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-06','req','RF04','caso','Subevento fora do periodo do principal','esperado','ERRO:SUBEVENTO_FORA_DO_PERIODO','obtido', r);

  r := pg_temp.q(format($s$insert into bloqueios_local(local_id,inicio,fim,motivo) values (%L,'2027-04-01 08:00-03','2027-04-01 18:00-03','manutencao') returning id::text$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-07','req','RF02','caso','Criar bloqueio de agenda do local','esperado','ok','obtido', case when r like 'ERRO:%' then r else 'ok' end);

  r := pg_temp.q(format($s$insert into eventos(titulo,local_id,inicio,fim,vagas) values ('Em bloqueio',%L,'2027-04-01 09:00-03','2027-04-01 10:00-03',2) returning id::text$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-08','req','RF02','caso','Evento dentro de periodo bloqueado','esperado','ERRO:LOCAL_BLOQUEADO','obtido', r);

  r := pg_temp.q(format($s$insert into bloqueios_local(local_id,inicio,fim) values (%L,'2027-03-01 11:00-03','2027-03-01 13:00-03')$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-09','req','RF02','caso','Bloqueio sobre evento ja marcado','esperado','ERRO:CONFLITO_COM_EVENTO','obtido', r);

  r := pg_temp.q(format($s$insert into bloqueios_local(local_id,inicio,fim) values (%L,'2027-04-01 10:00-03','2027-04-01 11:00-03') returning id::text$s$, l1));
  v_res := v_res || jsonb_build_object('id','TC-DB-10','req','RF02','caso','Bloqueios sobrepostos no mesmo local','esperado','ERRO:conflicting key value violates exclusion constraint','obtido', left(r, 62));

  -- ===== inscricoes e fila =====
  insert into eventos(titulo,local_id,inicio,fim,vagas) values ('E2',l2,'2027-05-01 10:00-03','2027-05-01 12:00-03',2) returning id into e2;

  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,false)$s$, e1, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-11','req','RN03','caso','Inscricao com vaga disponivel','esperado','CONFIRMADA','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,false)$s$, e1, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-12','req','RN06','caso','Inscricao duplicada no mesmo evento','esperado','ERRO:INSCRICAO_DUPLICADA','obtido', r);

  perform fn_inscrever(e2, u1, false);
  perform fn_inscrever(e2, u2, false);
  r := pg_temp.q(format($s$select estado::text from eventos where id=%L$s$, e2));
  v_res := v_res || jsonb_build_object('id','TC-DB-13','req','RN04','caso','Evento passa a LOTADO ao preencher as vagas','esperado','LOTADO','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,false)$s$, e2, u3));
  v_res := v_res || jsonb_build_object('id','TC-DB-14','req','RN04','caso','Inscricao em evento lotado sem entrar na fila','esperado','ERRO:EVENTO_LOTADO','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,true)$s$, e2, u3));
  v_res := v_res || jsonb_build_object('id','TC-DB-15','req','RN04','caso','Entrar na fila de espera com evento lotado','esperado','EM_ESPERA','obtido', r);
  perform fn_inscrever(e2, u4, true);

  select id into i1 from inscricoes where evento_id=e2 and usuario_id=u1;
  select id into i2 from inscricoes where evento_id=e2 and usuario_id=u2;
  select id into i3 from inscricoes where evento_id=e2 and usuario_id=u3;
  select id into i4 from inscricoes where evento_id=e2 and usuario_id=u4;

  r := pg_temp.q(format($s$select status::text from fn_cancelar_inscricao(%L,%L)$s$, i2, u3));
  v_res := v_res || jsonb_build_object('id','TC-DB-16','req','RN07','caso','Cancelar inscricao de outro participante','esperado','ERRO:SEM_PERMISSAO','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_cancelar_inscricao(%L,%L)$s$, i1, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-17','req','RF06','caso','Cancelar a propria inscricao','esperado','CANCELADA','obtido', r);

  r := pg_temp.q(format($s$select status::text from inscricoes where id=%L$s$, i3));
  v_res := v_res || jsonb_build_object('id','TC-DB-18','req','RN05','caso','Cancelamento promove o primeiro da fila (FIFO)','esperado','CONFIRMADA','obtido', r);

  r := pg_temp.q(format($s$select status::text from inscricoes where id=%L$s$, i4));
  v_res := v_res || jsonb_build_object('id','TC-DB-19','req','RN05','caso','Segundo da fila continua em espera','esperado','EM_ESPERA','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_cancelar_inscricao(%L,%L)$s$, i1, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-20','req','RF06','caso','Cancelar inscricao ja cancelada','esperado','ERRO:INSCRICAO_JA_CANCELADA','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,true)$s$, e2, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-21','req','RN06','caso','Reinscricao apos cancelamento (entra na fila)','esperado','EM_ESPERA','obtido', r);

  r := pg_temp.q(format($s$select vagas::text from fn_ajustar_vagas(%L,1)$s$, e2));
  v_res := v_res || jsonb_build_object('id','TC-DB-22','req','RF11','caso','Reduzir vagas abaixo dos confirmados','esperado','ERRO:VAGAS_MENORES_QUE_CONFIRMADOS','obtido', r);

  r := pg_temp.q(format($s$select vagas::text from fn_ajustar_vagas(%L,3)$s$, e2));
  v_res := v_res || jsonb_build_object('id','TC-DB-23','req','RF11','caso','Aumentar vagas (limite da capacidade)','esperado','3','obtido', r);

  r := pg_temp.q(format($s$select status::text from inscricoes where id=%L$s$, i4));
  v_res := v_res || jsonb_build_object('id','TC-DB-24','req','RF07','caso','Aumento de vagas promove proximo da fila','esperado','CONFIRMADA','obtido', r);

  r := pg_temp.q(format($s$select vagas::text from fn_ajustar_vagas(%L,4)$s$, e2));
  v_res := v_res || jsonb_build_object('id','TC-DB-25','req','RN03','caso','Ajustar vagas acima da capacidade do local','esperado','ERRO:CAPACIDADE_EXCEDIDA','obtido', r);

  -- ===== check-in =====
  select codigo_checkin into cod2 from inscricoes where id=i2;
  select codigo_checkin into cod3 from inscricoes where id=i3;
  select id into i5 from inscricoes where evento_id=e2 and usuario_id=u1;

  r := pg_temp.q(format($s$select id::text from fn_registrar_checkin(%L,%L,%L)$s$, cod2, e2, adm));
  v_res := v_res || jsonb_build_object('id','TC-DB-26','req','RN07','caso','Check-in de inscrito confirmado','esperado','ok','obtido', case when r like 'ERRO:%' then r else 'ok' end);

  r := pg_temp.q(format($s$select id::text from fn_registrar_checkin(%L,%L,%L)$s$, cod2, e2, adm));
  v_res := v_res || jsonb_build_object('id','TC-DB-27','req','RN08','caso','Segundo check-in da mesma inscricao','esperado','ERRO:CHECKIN_JA_REGISTRADO','obtido', r);

  r := pg_temp.q(format($s$select id::text from fn_registrar_checkin(%L,%L,%L)$s$, cod3, e1, adm));
  v_res := v_res || jsonb_build_object('id','TC-DB-28','req','RN07','caso','Check-in com codigo de outro evento','esperado','ERRO:INSCRICAO_OUTRO_EVENTO','obtido', r);

  r := pg_temp.q(format($s$select id::text from fn_registrar_checkin(%L,%L,%L)$s$, (select codigo_checkin from inscricoes where id=i5), e2, adm));
  v_res := v_res || jsonb_build_object('id','TC-DB-29','req','RN07','caso','Check-in de inscricao em espera','esperado','ERRO:INSCRICAO_NAO_CONFIRMADA','obtido', r);

  r := pg_temp.q(format($s$select id::text from fn_registrar_checkin(%L,%L,%L)$s$, gen_random_uuid(), e2, adm));
  v_res := v_res || jsonb_build_object('id','TC-DB-30','req','RN07','caso','Check-in com codigo inexistente','esperado','ERRO:CODIGO_INVALIDO','obtido', r);

  r := pg_temp.q(format($s$update checkins set registrado_em = now() - interval '1 day' where inscricao_id=%L returning id::text$s$, i2));
  v_res := v_res || jsonb_build_object('id','TC-DB-31','req','RNF07','caso','Alterar um check-in ja registrado','esperado','ERRO:CHECKIN_IMUTAVEL','obtido', r);

  r := pg_temp.q(format($s$delete from checkins where inscricao_id=%L returning id::text$s$, i2));
  v_res := v_res || jsonb_build_object('id','TC-DB-32','req','RNF07','caso','Apagar um check-in ja registrado','esperado','ERRO:CHECKIN_IMUTAVEL','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_cancelar_inscricao(%L,%L)$s$, i2, u2));
  v_res := v_res || jsonb_build_object('id','TC-DB-33','req','RF06','caso','Cancelar inscricao que ja tem presenca','esperado','ERRO:CHECKIN_JA_REGISTRADO','obtido', r);

  -- ===== certificados =====
  r := pg_temp.q(format($s$select id::text from fn_emitir_certificado(%L,%L)$s$, i3, u3));
  v_res := v_res || jsonb_build_object('id','TC-DB-34','req','RN09','caso','Certificado sem presenca registrada','esperado','ERRO:SEM_PRESENCA','obtido', r);

  r := pg_temp.q(format($s$select id::text from fn_emitir_certificado(%L,%L)$s$, i2, u2));
  v_res := v_res || jsonb_build_object('id','TC-DB-35','req','RN09','caso','Certificado de evento que ainda nao terminou','esperado','ERRO:EVENTO_NAO_CONCLUIDO','obtido', r);

  -- evento ja realizado (dados inseridos direto, pois a inscricao pela funcao exige evento futuro)
  insert into eventos(titulo,local_id,inicio,fim,vagas,carga_horaria) values ('E3 passado',l1,'2026-01-10 10:00-03','2026-01-10 12:00-03',5,2) returning id into e3;
  insert into inscricoes(evento_id,usuario_id,status) values (e3,u1,'CONFIRMADA') returning id, codigo_checkin into i_old, cod_old;
  insert into inscricoes(evento_id,usuario_id,status) values (e3,u2,'CONFIRMADA') returning id into i_old2;
  perform fn_registrar_checkin(cod_old, e3, adm);

  r := pg_temp.q(format($s$select length(codigo_verificacao)::text from fn_emitir_certificado(%L,%L)$s$, i_old, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-36','req','RN09/RN10','caso','Certificado emitido com presenca (codigo de 64 caracteres)','esperado','64','obtido', r);

  r := pg_temp.q(format($s$select (select count(*) from certificados where inscricao_id=%L)::text from fn_emitir_certificado(%L,%L)$s$, i_old, i_old, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-37','req','RN10','caso','Emitir de novo nao duplica o certificado','esperado','1','obtido', r);

  select codigo_verificacao into v_cert from certificados where inscricao_id=i_old;
  r := pg_temp.q(format($s$select participante from fn_verificar_certificado(%L)$s$, v_cert));
  v_res := v_res || jsonb_build_object('id','TC-DB-38','req','RF10','caso','Verificar certificado valido','esperado','Participante Um','obtido', r);

  r := pg_temp.q($s$select (select count(*) from fn_verificar_certificado('000000'))::text$s$);
  v_res := v_res || jsonb_build_object('id','TC-DB-39','req','RF10','caso','Verificar certificado inexistente','esperado','0','obtido', r);

  r := pg_temp.q($s$select (fn_concluir_eventos_finalizados() >= 1)::text$s$);
  v_res := v_res || jsonb_build_object('id','TC-DB-40','req','RF04','caso','Rotina marca eventos terminados como REALIZADO','esperado','true','obtido', r);

  r := pg_temp.q(format($s$select estado::text from eventos where id=%L$s$, e3));
  v_res := v_res || jsonb_build_object('id','TC-DB-41','req','RF04','caso','Estado do evento passado apos a rotina','esperado','REALIZADO','obtido', r);

  insert into eventos(titulo,local_id,inicio,fim,vagas,estado) values ('E4 encerrado',l1,'2027-06-01 10:00-03','2027-06-01 12:00-03',5,'ENCERRADO') returning id into e4;
  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,false)$s$, e4, u1));
  v_res := v_res || jsonb_build_object('id','TC-DB-42','req','RF04','caso','Inscricao em evento encerrado','esperado','ERRO:EVENTO_FECHADO','obtido', r);

  r := pg_temp.q(format($s$select status::text from fn_inscrever(%L,%L,false)$s$, e3, u3));
  v_res := v_res || jsonb_build_object('id','TC-DB-43','req','RF06','caso','Inscricao em evento que ja terminou','esperado','ERRO:EVENTO_FECHADO','obtido', r);

  -- ===== permissao e seguranca do banco =====
  r := pg_temp.q_anon('select count(*)::text from eventos');
  v_res := v_res || jsonb_build_object('id','TC-DB-44','req','RNF06','caso','Leitura de eventos pela role publica anon (API REST do Supabase)','esperado','ERRO:permission denied','obtido', left(r, 28));

  r := pg_temp.q_anon($s$select (fn_concluir_eventos_finalizados())::text$s$);
  v_res := v_res || jsonb_build_object('id','TC-DB-45','req','RNF06','caso','Execucao de funcao de regra pela role anon','esperado','ERRO:permission denied','obtido', left(r, 28));

  r := pg_temp.q($s$select (select count(*) from pg_tables where schemaname='public' and not rowsecurity)::text$s$);
  v_res := v_res || jsonb_build_object('id','TC-DB-46','req','RNF06','caso','Tabelas do schema public sem RLS ligado','esperado','0','obtido', r);

  -- desfaz tudo e devolve o resultado na mensagem
  raise exception 'RESULTADO %', v_res::text;
end
$teste$;
