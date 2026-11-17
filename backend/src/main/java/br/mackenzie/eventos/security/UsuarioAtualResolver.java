package br.mackenzie.eventos.security;

import java.util.Collection;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

/**
 * A identidade e gerenciada pelo Keycloak. No primeiro acesso (e a cada requisicao, de forma idempotente)
 * o usuario e sincronizado na tabela "usuarios" usando o claim "sub" como chave.
 */
@Component
public class UsuarioAtualResolver {

    private final JdbcClient jdbc;

    public UsuarioAtualResolver(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public UsuarioAtual resolver(Jwt jwt) {
        boolean admin = false;
        Map<String, Object> realmAccess = jwt.getClaim("realm_access");
        if (realmAccess != null && realmAccess.get("roles") instanceof Collection<?> roles) {
            admin = roles.contains("ADMIN");
        }

        String nome = jwt.getClaimAsString("name");
        if (nome == null || nome.isBlank()) {
            nome = jwt.getClaimAsString("preferred_username");
        }
        if (nome == null || nome.isBlank()) {
            nome = "Usuário";
        }
        String email = jwt.getClaimAsString("email");
        if (email == null || email.isBlank()) {
            email = jwt.getSubject() + "@sem-email.local";
        }

        return jdbc.sql("""
                insert into usuarios (keycloak_id, nome, email, perfil)
                values (:kid, :nome, :email, cast(:perfil as perfil_usuario))
                on conflict (keycloak_id) do update
                   set nome = excluded.nome, email = excluded.email, perfil = excluded.perfil
                returning id, nome, email, perfil::text as perfil
                """)
            .param("kid", jwt.getSubject())
            .param("nome", nome)
            .param("email", email)
            .param("perfil", admin ? "ADMIN" : "PARTICIPANTE")
            .query(UsuarioAtual.class)
            .single();
    }
}
