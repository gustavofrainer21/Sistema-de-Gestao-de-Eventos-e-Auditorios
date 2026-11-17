package br.mackenzie.eventos.web;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import br.mackenzie.eventos.security.UsuarioAtual;
import br.mackenzie.eventos.security.UsuarioAtualResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** RF04 (gestao de eventos), RF05 (catalogo) e RF11 (painel administrativo). */
@RestController
public class EventoController {

    public record Evento(UUID id, UUID eventoPaiId, String titulo, String descricao,
                         UUID localId, String localNome, String localizacao,
                         OffsetDateTime inicio, OffsetDateTime fim, int vagas, String estado,
                         BigDecimal cargaHoraria, long confirmados, long emEspera) {}

    public record EventoForm(UUID eventoPaiId,
                             @NotBlank String titulo,
                             String descricao,
                             @NotNull UUID localId,
                             @NotNull OffsetDateTime inicio,
                             @NotNull OffsetDateTime fim,
                             @Min(0) int vagas,
                             @NotNull @Positive BigDecimal cargaHoraria) {}

    public record VagasForm(@Min(0) int vagas) {}

    public record Detalhe(Evento evento, List<Evento> subeventos) {}

    public record Inscrito(UUID inscricaoId, UUID usuarioId, String nome, String email, String status,
                           OffsetDateTime criadoEm, boolean presente) {}

    public record Painel(UUID eventoId, String titulo, String estado, int vagas,
                         long confirmados, long emEspera, long presencas, long certificados) {}

    private static final String SELECT_EVENTO = """
            select e.id, e.evento_pai_id, e.titulo, e.descricao, e.local_id,
                   l.nome as local_nome, l.localizacao,
                   e.inicio, e.fim, e.vagas, e.estado::text as estado, e.carga_horaria,
                   (select count(*) from inscricoes i where i.evento_id = e.id and i.status = 'CONFIRMADA') as confirmados,
                   (select count(*) from inscricoes i where i.evento_id = e.id and i.status = 'EM_ESPERA') as em_espera
            from eventos e join locais l on l.id = e.local_id
            """;

    private final JdbcClient jdbc;
    private final UsuarioAtualResolver usuarios;

    public EventoController(JdbcClient jdbc, UsuarioAtualResolver usuarios) {
        this.jdbc = jdbc;
        this.usuarios = usuarios;
    }

    /** RF05: catalogo. Participante ve eventos abertos/lotados que ainda nao terminaram; admin ve todos. */
    @GetMapping("/api/eventos")
    public List<Evento> catalogo(@AuthenticationPrincipal Jwt jwt) {
        UsuarioAtual u = usuarios.resolver(jwt);
        return jdbc.sql(SELECT_EVENTO + """
                where e.evento_pai_id is null
                  and (:admin or (e.estado in ('ABERTO', 'LOTADO') and e.fim > now()))
                order by e.inicio
                """)
            .param("admin", u.admin())
            .query(Evento.class).list();
    }

    @GetMapping("/api/eventos/{id}")
    public Detalhe detalhe(@PathVariable UUID id) {
        Evento evento = jdbc.sql(SELECT_EVENTO + " where e.id = :id").param("id", id).query(Evento.class).single();
        List<Evento> subs = jdbc.sql(SELECT_EVENTO + " where e.evento_pai_id = :id order by e.inicio")
            .param("id", id).query(Evento.class).list();
        return new Detalhe(evento, subs);
    }

    @PostMapping("/api/eventos")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public Evento criar(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody EventoForm f) {
        validarPeriodo(f);
        UsuarioAtual u = usuarios.resolver(jwt);
        UUID id = jdbc.sql("""
                insert into eventos (evento_pai_id, titulo, descricao, local_id, inicio, fim, vagas, carga_horaria, criado_por)
                values (:pai, :titulo, :descricao, :local, :ini, :fim, :vagas, :carga, :autor)
                returning id
                """)
            .param("pai", f.eventoPaiId()).param("titulo", f.titulo()).param("descricao", f.descricao())
            .param("local", f.localId()).param("ini", f.inicio()).param("fim", f.fim())
            .param("vagas", f.vagas()).param("carga", f.cargaHoraria()).param("autor", u.id())
            .query(UUID.class).single();
        return jdbc.sql(SELECT_EVENTO + " where e.id = :id").param("id", id).query(Evento.class).single();
    }

    @PutMapping("/api/eventos/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Evento alterar(@PathVariable UUID id, @Valid @RequestBody EventoForm f) {
        validarPeriodo(f);
        int n = jdbc.sql("""
                update eventos set titulo = :titulo, descricao = :descricao, local_id = :local,
                                   inicio = :ini, fim = :fim, carga_horaria = :carga
                where id = :id and estado in ('ABERTO', 'LOTADO')
                """)
            .param("id", id).param("titulo", f.titulo()).param("descricao", f.descricao())
            .param("local", f.localId()).param("ini", f.inicio()).param("fim", f.fim())
            .param("carga", f.cargaHoraria())
            .update();
        if (n == 0) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "EVENTO_FECHADO",
                "Evento inexistente, encerrado ou já realizado.");
        }
        // vagas passam pela funcao que valida inscritos confirmados e promove a fila
        jdbc.sql("select (fn_ajustar_vagas(:id, :vagas)).id").param("id", id).param("vagas", f.vagas())
            .query(UUID.class).single();
        return jdbc.sql(SELECT_EVENTO + " where e.id = :id").param("id", id).query(Evento.class).single();
    }

    /** RF11: ajuste de vagas (promove automaticamente quem estiver na fila se houver novas vagas). */
    @PatchMapping("/api/eventos/{id}/vagas")
    @PreAuthorize("hasRole('ADMIN')")
    public Evento ajustarVagas(@PathVariable UUID id, @Valid @RequestBody VagasForm f) {
        jdbc.sql("select (fn_ajustar_vagas(:id, :vagas)).id").param("id", id).param("vagas", f.vagas())
            .query(UUID.class).single();
        return jdbc.sql(SELECT_EVENTO + " where e.id = :id").param("id", id).query(Evento.class).single();
    }

    @PostMapping("/api/eventos/{id}/encerrar")
    @PreAuthorize("hasRole('ADMIN')")
    public Evento encerrar(@PathVariable UUID id) {
        int n = jdbc.sql("update eventos set estado = 'ENCERRADO' where id = :id and estado in ('ABERTO', 'LOTADO')")
            .param("id", id).update();
        if (n == 0) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "EVENTO_FECHADO",
                "Evento inexistente, encerrado ou já realizado.");
        }
        return jdbc.sql(SELECT_EVENTO + " where e.id = :id").param("id", id).query(Evento.class).single();
    }

    @GetMapping("/api/eventos/{id}/inscritos")
    @PreAuthorize("hasRole('ADMIN')")
    public List<Inscrito> inscritos(@PathVariable UUID id) {
        return jdbc.sql("""
                select i.id as inscricao_id, u.id as usuario_id, u.nome, u.email, i.status::text as status,
                       i.criado_em, exists (select 1 from checkins k where k.inscricao_id = i.id) as presente
                from inscricoes i join usuarios u on u.id = i.usuario_id
                where i.evento_id = :id and i.status <> 'CANCELADA'
                order by case i.status when 'CONFIRMADA' then 0 else 1 end, i.ordem
                """)
            .param("id", id).query(Inscrito.class).list();
    }

    @GetMapping("/api/painel")
    @PreAuthorize("hasRole('ADMIN')")
    public List<Painel> painel() {
        return jdbc.sql("""
                select p.evento_id, p.titulo, p.estado::text as estado, p.vagas,
                       p.confirmados, p.em_espera, p.presencas, p.certificados
                from vw_painel_eventos p join eventos e on e.id = p.evento_id
                order by e.inicio desc
                """)
            .query(Painel.class).list();
    }

    private void validarPeriodo(EventoForm f) {
        if (!f.fim().isAfter(f.inicio())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PERIODO_INVALIDO", "O término deve ser após o início.");
        }
    }
}
