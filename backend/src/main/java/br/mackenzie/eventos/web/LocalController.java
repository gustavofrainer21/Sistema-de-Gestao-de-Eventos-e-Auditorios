package br.mackenzie.eventos.web;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** RF02 (cadastro de locais e bloqueios) e RF03 (consulta de disponibilidade). Somente ADMIN. */
@RestController
@RequestMapping("/api/locais")
@PreAuthorize("hasRole('ADMIN')")
public class LocalController {

    public record Local(UUID id, String nome, int capacidade, String localizacao, boolean ativo) {}

    public record LocalForm(@NotBlank String nome, @Min(1) int capacidade, @NotBlank String localizacao) {}

    public record Bloqueio(UUID id, UUID localId, OffsetDateTime inicio, OffsetDateTime fim, String motivo) {}

    public record BloqueioForm(@NotNull OffsetDateTime inicio, @NotNull OffsetDateTime fim, String motivo) {}

    private static final String SELECT_LOCAL = "select id, nome, capacidade, localizacao, ativo from locais";

    private final JdbcClient jdbc;

    public LocalController(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Local> listar() {
        return jdbc.sql(SELECT_LOCAL + " order by nome").query(Local.class).list();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Local criar(@Valid @RequestBody LocalForm f) {
        return jdbc.sql("""
                insert into locais (nome, capacidade, localizacao) values (:nome, :cap, :loc)
                returning id, nome, capacidade, localizacao, ativo
                """)
            .param("nome", f.nome()).param("cap", f.capacidade()).param("loc", f.localizacao())
            .query(Local.class).single();
    }

    @PutMapping("/{id}")
    public Local alterar(@PathVariable UUID id, @Valid @RequestBody LocalForm f) {
        return jdbc.sql("""
                update locais set nome = :nome, capacidade = :cap, localizacao = :loc where id = :id
                returning id, nome, capacidade, localizacao, ativo
                """)
            .param("id", id).param("nome", f.nome()).param("cap", f.capacidade()).param("loc", f.localizacao())
            .query(Local.class).single();
    }

    /** "Desativar" local (RF02): o historico e preservado, mas novos eventos nao podem usa-lo. */
    @PatchMapping("/{id}/ativo")
    public Local ativar(@PathVariable UUID id, @RequestParam boolean valor) {
        return jdbc.sql("""
                update locais set ativo = :valor where id = :id
                returning id, nome, capacidade, localizacao, ativo
                """)
            .param("id", id).param("valor", valor)
            .query(Local.class).single();
    }

    /** RF03: locais livres (sem evento nem bloqueio) na data/horario e com a capacidade desejada. */
    @GetMapping("/disponiveis")
    public List<Local> disponiveis(@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime inicio,
                                   @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime fim,
                                   @RequestParam(defaultValue = "1") int capacidade) {
        if (!fim.isAfter(inicio)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PERIODO_INVALIDO", "O término deve ser após o início.");
        }
        return jdbc.sql("""
                select l.id, l.nome, l.capacidade, l.localizacao, l.ativo
                from locais l
                where l.ativo and l.capacidade >= :cap
                  and not exists (select 1 from eventos e
                                   where e.local_id = l.id and e.estado in ('ABERTO', 'LOTADO')
                                     and tstzrange(e.inicio, e.fim) && tstzrange(cast(:ini as timestamptz), cast(:fim as timestamptz)))
                  and not exists (select 1 from bloqueios_local b
                                   where b.local_id = l.id
                                     and tstzrange(b.inicio, b.fim) && tstzrange(cast(:ini as timestamptz), cast(:fim as timestamptz)))
                order by l.capacidade, l.nome
                """)
            .param("cap", capacidade).param("ini", inicio).param("fim", fim)
            .query(Local.class).list();
    }

    @GetMapping("/{id}/bloqueios")
    public List<Bloqueio> bloqueios(@PathVariable UUID id) {
        return jdbc.sql("select id, local_id, inicio, fim, motivo from bloqueios_local where local_id = :id order by inicio")
            .param("id", id).query(Bloqueio.class).list();
    }

    @PostMapping("/{id}/bloqueios")
    @ResponseStatus(HttpStatus.CREATED)
    public Bloqueio bloquear(@PathVariable UUID id, @Valid @RequestBody BloqueioForm f) {
        if (!f.fim().isAfter(f.inicio())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PERIODO_INVALIDO", "O término deve ser após o início.");
        }
        return jdbc.sql("""
                insert into bloqueios_local (local_id, inicio, fim, motivo) values (:id, :ini, :fim, :motivo)
                returning id, local_id, inicio, fim, motivo
                """)
            .param("id", id).param("ini", f.inicio()).param("fim", f.fim()).param("motivo", f.motivo())
            .query(Bloqueio.class).single();
    }

    @DeleteMapping("/bloqueios/{bloqueioId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removerBloqueio(@PathVariable UUID bloqueioId) {
        jdbc.sql("delete from bloqueios_local where id = :id").param("id", bloqueioId).update();
    }
}
