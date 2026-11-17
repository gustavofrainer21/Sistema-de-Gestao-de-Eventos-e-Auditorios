package br.mackenzie.eventos.web;

import java.util.Map;

import org.postgresql.util.PSQLException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.IncorrectResultSizeDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Traduz os erros-codigo lancados pelas funcoes/triggers do PostgreSQL
 * (ex.: EVENTO_LOTADO, CONFLITO_AGENDA) em respostas HTTP com mensagem amigavel.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    public record Erro(String codigo, String mensagem) {}

    private record Def(HttpStatus status, String mensagem) {}

    private static final Map<String, Def> CODIGOS = Map.ofEntries(
        // 404
        Map.entry("EVENTO_NAO_ENCONTRADO", new Def(HttpStatus.NOT_FOUND, "Evento não encontrado.")),
        Map.entry("INSCRICAO_NAO_ENCONTRADA", new Def(HttpStatus.NOT_FOUND, "Inscrição não encontrada.")),
        Map.entry("CODIGO_INVALIDO", new Def(HttpStatus.NOT_FOUND, "Código de check-in inválido.")),
        // 403
        Map.entry("SEM_PERMISSAO", new Def(HttpStatus.FORBIDDEN, "Você não tem permissão para esta operação.")),
        // 409
        Map.entry("INSCRICAO_DUPLICADA", new Def(HttpStatus.CONFLICT, "Você já está inscrito neste evento.")),
        Map.entry("EVENTO_LOTADO", new Def(HttpStatus.CONFLICT, "O evento está lotado. Você pode entrar na fila de espera.")),
        Map.entry("CONFLITO_AGENDA", new Def(HttpStatus.CONFLICT, "Já existe um evento neste local e horário.")),
        Map.entry("LOCAL_BLOQUEADO", new Def(HttpStatus.CONFLICT, "O local está bloqueado neste período.")),
        Map.entry("CONFLITO_COM_EVENTO", new Def(HttpStatus.CONFLICT, "O período do bloqueio conflita com um evento já marcado.")),
        Map.entry("CHECKIN_JA_REGISTRADO", new Def(HttpStatus.CONFLICT, "Check-in já registrado para esta inscrição.")),
        Map.entry("INSCRICAO_JA_CANCELADA", new Def(HttpStatus.CONFLICT, "Esta inscrição já foi cancelada.")),
        // 422
        Map.entry("CAPACIDADE_EXCEDIDA", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "O número de vagas excede a capacidade do local.")),
        Map.entry("LOCAL_INATIVO", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "O local está desativado.")),
        Map.entry("EVENTO_PAI_INVALIDO", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "Evento principal inválido (subeventos têm apenas um nível).")),
        Map.entry("SUBEVENTO_FORA_DO_PERIODO", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "O subevento deve ocorrer dentro do período do evento principal.")),
        Map.entry("EVENTO_FECHADO", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "O evento está encerrado ou já foi realizado.")),
        Map.entry("VAGAS_MENORES_QUE_CONFIRMADOS", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "O número de vagas não pode ser menor que o de inscritos confirmados.")),
        Map.entry("INSCRICAO_OUTRO_EVENTO", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "Esta inscrição pertence a outro evento.")),
        Map.entry("INSCRICAO_NAO_CONFIRMADA", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "A inscrição não está confirmada.")),
        Map.entry("SEM_PRESENCA", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "Certificado disponível apenas para quem teve presença registrada.")),
        Map.entry("EVENTO_NAO_CONCLUIDO", new Def(HttpStatus.UNPROCESSABLE_ENTITY, "O certificado só pode ser emitido após o término do evento."))
    );

    @ExceptionHandler(ApiException.class)
    ResponseEntity<Erro> api(ApiException e) {
        return ResponseEntity.status(e.status()).body(new Erro(e.codigo(), e.getMessage()));
    }

    @ExceptionHandler(IncorrectResultSizeDataAccessException.class)
    ResponseEntity<Erro> naoEncontrado(IncorrectResultSizeDataAccessException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(new Erro("NAO_ENCONTRADO", "Registro não encontrado."));
    }

    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<Erro> banco(DataAccessException e) {
        Throwable causa = NestedExceptionUtils.getMostSpecificCause(e);
        String codigo = String.valueOf(causa.getMessage());
        if (causa instanceof PSQLException p) {
            if (p.getServerErrorMessage() != null && p.getServerErrorMessage().getMessage() != null) {
                codigo = p.getServerErrorMessage().getMessage();
            }
            if ("23P01".equals(p.getSQLState())) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new Erro("CONFLITO_AGENDA", CODIGOS.get("CONFLITO_AGENDA").mensagem()));
            }
        }
        Def def = CODIGOS.get(codigo.trim());
        if (def != null) {
            return ResponseEntity.status(def.status()).body(new Erro(codigo.trim(), def.mensagem()));
        }
        if (e instanceof DuplicateKeyException) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new Erro("DADO_DUPLICADO", "Já existe um registro com estes dados."));
        }
        if (e instanceof DataIntegrityViolationException) {
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
                .body(new Erro("DADOS_INVALIDOS", "Os dados informados são inválidos."));
        }
        log.error("Erro de banco de dados", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(new Erro("ERRO_INTERNO", "Erro interno. Tente novamente."));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Erro> validacao(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
            .findFirst().map(f -> f.getField() + ": " + f.getDefaultMessage()).orElse("Dados inválidos.");
        return ResponseEntity.badRequest().body(new Erro("VALIDACAO", msg));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<Erro> corpoInvalido(HttpMessageNotReadableException e) {
        return ResponseEntity.badRequest().body(new Erro("CORPO_INVALIDO", "Corpo da requisição inválido."));
    }
}
