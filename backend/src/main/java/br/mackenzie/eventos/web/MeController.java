package br.mackenzie.eventos.web;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import br.mackenzie.eventos.security.UsuarioAtual;
import br.mackenzie.eventos.security.UsuarioAtualResolver;

@RestController
public class MeController {

    private final UsuarioAtualResolver usuarios;

    public MeController(UsuarioAtualResolver usuarios) {
        this.usuarios = usuarios;
    }

    /** RF01: usuario logado e seu perfil (usado pelo front-end para montar o menu). */
    @GetMapping("/api/me")
    public UsuarioAtual me(@AuthenticationPrincipal Jwt jwt) {
        return usuarios.resolver(jwt);
    }
}
