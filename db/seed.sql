-- Dados iniciais (ja aplicados no projeto Supabase "gestao-eventos-auditorios")
insert into locais (nome, capacidade, localizacao) values
  ('Auditório Principal', 300, 'Prédio 1 – Térreo'),
  ('Auditório Menor', 120, 'Prédio 2 – 1º andar'),
  ('Sala de Workshop 01', 40, 'Prédio 3 – 2º andar')
on conflict (nome) do nothing;
