package br.mackenzie.eventos.security;

import java.util.UUID;

/** Usuario do dominio correspondente ao token Keycloak da requisicao. perfil: ADMIN ou PARTICIPANTE. */
public record UsuarioAtual(UUID id, String nome, String email, String perfil) {

    public boolean admin() {
        return "ADMIN".equals(perfil);
    }
}
