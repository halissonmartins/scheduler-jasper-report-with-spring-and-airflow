package br.com.relatorios.comum.seguranca;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * O caso POSITIVO é o que importa aqui.
 *
 * <p>O modo de falha deste conversor é autorização silenciosamente vazia, não exceção —
 * um teste que só verifique "403 quando não autorizado" passaria mesmo com ele quebrado.
 */
class ConversorDeAuthoritiesTest {

    private final ConversorDeAuthorities conversor = new ConversorDeAuthorities("relatorios");

    private static Jwt jwt(Map<String, Object> claims) {
        return new Jwt("t", Instant.now(), Instant.now().plusSeconds(300),
                Map.of("alg", "RS256"), claims);
    }

    @Test
    @DisplayName("lê o Perfil de realm_access e a Role de Relatório de resource_access")
    void leAsDuasClaims() {
        Jwt token = jwt(Map.of(
                "sub", "u-1",
                "realm_access", Map.of("roles", List.of("RELATOR")),
                "resource_access", Map.of("relatorios",
                        Map.of("roles", List.of("REL_POUPANCA_GERENCIAL")))));

        assertThat(conversor.convert(token))
                .extracting(GrantedAuthority::getAuthority)
                .containsExactlyInAnyOrder("ROLE_RELATOR", "ROLE_REL_POUPANCA_GERENCIAL");
    }

    @Test
    @DisplayName("ignora as roles de outro client — elas não são deste sistema")
    void ignoraOutroClient() {
        Jwt token = jwt(Map.of(
                "sub", "u-1",
                "realm_access", Map.of("roles", List.of("RELATOR")),
                "resource_access", Map.of("outro-sistema",
                        Map.of("roles", List.of("QUALQUER_COISA")))));

        assertThat(conversor.convert(token))
                .extracting(GrantedAuthority::getAuthority)
                .containsExactly("ROLE_RELATOR");
    }

    @Test
    @DisplayName("token sem claim alguma não explode — devolve vazio")
    void tokenSemClaims() {
        assertThat(conversor.convert(jwt(Map.of("sub", "u-1")))).isEmpty();
    }
}
