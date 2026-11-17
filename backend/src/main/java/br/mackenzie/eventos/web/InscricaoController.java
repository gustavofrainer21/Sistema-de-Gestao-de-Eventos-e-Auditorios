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
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import br.mackenzie.eventos.security.UsuarioAtual;
import br.mackenzie.eventos.security.UsuarioAtualResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

/**
 * RF06 (inscricao), RF07 (fila), RF08 (area do participante), RF09 (check-in) e RF10 (certificados).
 * As regras de negocio vivem nas funcoes do PostgreSQL (ver db/migrations/002_funcoes.sql).
 */
@RestController
public class InscricaoController {

    public record Inscricao(UUID id, UUID eventoId, UUID usuarioId, String status, UUID codigoCheckin,
                            OffsetDateTime criadoEm) {}

    public record MinhaInscricao(UUID id, UUID eventoId, String eventoTitulo, String estadoEvento,
                                 OffsetDateTime inicio, OffsetDateTime fim, String localNome, String status,
                                 Long posicaoFila, UUID codigoCheckin, boolean presente,
                                 String codigoCertificado) {}

    public record Certificado(UUID id, UUID inscricaoId, String codigoVerificacao, OffsetDateTime emitidoEm,
                              BigDecimal cargaHoraria) {}

    public record CertificadoDados(String participante, String evento, OffsetDateTime dataEvento,
                                   BigDecimal cargaHoraria, OffsetDateTime emitidoEm, String codigo) {}

    public record CheckinForm(@NotBlank String codigo) {}

    public record CheckinResultado(boolean aceito, String participante, OffsetDateTime registradoEm) {}

    public record CertificadoVerificado(boolean valido, String participante, String evento,
                                        OffsetDateTime dataEvento, BigDecimal cargaHoraria,
                                        OffsetDateTime emitidoEm) {}

    private final JdbcClient jdbc;
    private final UsuarioAtualResolver usuarios;

    public InscricaoController(JdbcClient jdbc, UsuarioAtualResolver usuarios) {
        this.jdbc = jdbc;
        this.usuarios = usuarios;
    }

    /** RF06/RF07: inscreve; se lotado e fila=true, entra na fila de espera. */
    @PostMapping("/api/eventos/{eventoId}/inscricoes")
    @ResponseStatus(HttpStatus.CREATED)
    public Inscricao inscrever(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID eventoId,
                               @RequestParam(defaultValue = "false") boolean fila) {
        UsuarioAtual u = usuarios.resolver(jwt);
        return jdbc.sql("""
                select id, evento_id, usuario_id, status::text as status, codigo_checkin, criado_em
                from fn_inscrever(:evento, :usuario, :fila)
                """)
            .param("evento", eventoId).param("usuario", u.id()).param("fila", fila)
            .query(Inscricao.class).single();
    }

    /** RF08: area do participante. */
    @GetMapping("/api/inscricoes/minhas")
    public List<MinhaInscricao> minhas(@AuthenticationPrincipal Jwt jwt) {
        UsuarioAtual u = usuarios.resolver(jwt);
        return jdbc.sql("""
                select i.id, i.evento_id, e.titulo as evento_titulo, e.estado::text as estado_evento,
                       e.inicio, e.fim, l.nome as local_nome, i.status::text as status,
                       case when i.status = 'EM_ESPERA' then
                            (select count(*) from inscricoes x
                              where x.evento_id = i.evento_id and x.status = 'EM_ESPERA' and x.ordem <= i.ordem)
                       end as posicao_fila,
                       case when i.status = 'CONFIRMADA' then i.codigo_checkin end as codigo_checkin,
                       exists (select 1 from checkins k where k.inscricao_id = i.id) as presente,
                       c.codigo_verificacao as codigo_certificado
                from inscricoes i
                join eventos e on e.id = i.evento_id
                join locais l on l.id = e.local_id
                left join certificados c on c.inscricao_id = i.id
                where i.usuario_id = :u
                order by e.inicio desc
                """)
            .param("u", u.id()).query(MinhaInscricao.class).list();
    }

    /** Cancela (e promove o proximo da fila). O admin pode cancelar a de qualquer um. */
    @DeleteMapping("/api/inscricoes/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelar(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UsuarioAtual u = usuarios.resolver(jwt);
        jdbc.sql("select (fn_cancelar_inscricao(:id, cast(:u as uuid))).id")
            .param("id", id).param("u", u.admin() ? null : u.id())
            .query(UUID.class).single();
    }

    /** RF10: emite (idempotente) o certificado da inscricao com presenca. */
    @PostMapping("/api/inscricoes/{id}/certificado")
    public Certificado emitirCertificado(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UsuarioAtual u = usuarios.resolver(jwt);
        return jdbc.sql("""
                select id, inscricao_id, codigo_verificacao, emitido_em, carga_horaria
                from fn_emitir_certificado(:id, cast(:u as uuid))
                """)
            .param("id", id).param("u", u.admin() ? null : u.id())
            .query(Certificado.class).single();
    }

    /** Dados para exibir/imprimir o certificado (dono da inscricao ou admin). */
    @GetMapping("/api/inscricoes/{id}/certificado")
    public CertificadoDados certificado(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        UsuarioAtual u = usuarios.resolver(jwt);
        return jdbc.sql("""
                select pu.nome as participante, e.titulo as evento, e.inicio as data_evento,
                       c.carga_horaria, c.emitido_em, c.codigo_verificacao as codigo
                from certificados c
                join inscricoes i on i.id = c.inscricao_id
                join usuarios pu on pu.id = i.usuario_id
                join eventos e on e.id = i.evento_id
                where i.id = :id and (:admin or i.usuario_id = :u)
                """)
            .param("id", id).param("admin", u.admin()).param("u", u.id())
            .query(CertificadoDados.class).single();
    }

    /** RF09: validacao de check-in pelo organizador. 200 = aceito; erros trazem o motivo da rejeicao. */
    @PostMapping("/api/eventos/{eventoId}/checkin")
    @PreAuthorize("hasRole('ADMIN')")
    public CheckinResultado checkin(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID eventoId,
                                    @Valid @RequestBody CheckinForm f) {
        UsuarioAtual u = usuarios.resolver(jwt);
        UUID codigo;
        try {
            codigo = UUID.fromString(f.codigo().trim());
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.NOT_FOUND, "CODIGO_INVALIDO", "Código de check-in inválido.");
        }
        return jdbc.sql("""
                select true as aceito, pu.nome as participante, k.registrado_em
                from fn_registrar_checkin(:codigo, :evento, :validador) k
                join inscricoes i on i.id = k.inscricao_id
                join usuarios pu on pu.id = i.usuario_id
                """)
            .param("codigo", codigo).param("evento", eventoId).param("validador", u.id())
            .query(CheckinResultado.class).single();
    }

    /** RF10/UC14: verificacao de validade de certificado pelo codigo. */
    @GetMapping("/api/certificados/verificar/{codigo}")
    @PreAuthorize("hasRole('ADMIN')")
    public CertificadoVerificado verificar(@PathVariable String codigo) {
        List<CertificadoVerificado> r = jdbc.sql("""
                select true as valido, participante, evento, data_evento, carga_horaria, emitido_em
                from fn_verificar_certificado(:codigo)
                """)
            .param("codigo", codigo).query(CertificadoVerificado.class).list();
        if (r.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "CERTIFICADO_INVALIDO", "Certificado não encontrado ou inválido.");
        }
        return r.get(0);
    }
}
