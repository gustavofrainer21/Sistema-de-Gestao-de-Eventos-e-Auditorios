package br.mackenzie.eventos;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Marca como REALIZADO os eventos cujo horario terminou (libera a emissao de certificados). */
@Component
public class EventoScheduler {

    private static final Logger log = LoggerFactory.getLogger(EventoScheduler.class);

    private final JdbcClient jdbc;

    public EventoScheduler(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Scheduled(fixedDelay = 60_000, initialDelay = 30_000)
    public void concluirEventos() {
        try {
            Integer n = jdbc.sql("select fn_concluir_eventos_finalizados()").query(Integer.class).single();
            if (n != null && n > 0) {
                log.info("{} evento(s) marcado(s) como REALIZADO", n);
            }
        } catch (Exception e) {
            log.warn("Falha ao concluir eventos finalizados: {}", e.getMessage());
        }
    }
}
