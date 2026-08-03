package br.com.relatorios.api.saude;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.actuate.endpoint.web.WebEndpointsSupplier;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Prova que o actuator serve <strong>apenas</strong> {@code health}.
 *
 * <p>Este teste olha o conjunto de endpoints <em>expostos</em>, e não o código HTTP de uma
 * requisição. A distinção importa e foi identificada no ticket 33: {@code /actuator/env}
 * responde <strong>401</strong>, não 404, porque o Spring Security intercepta antes de a
 * exposição sequer importar. Um teste por HTTP passaria pelo motivo errado — e continuaria
 * verde se alguém incluísse {@code *} em
 * {@code management.endpoints.web.exposure.include} "para facilitar o debug".
 */
@SpringBootTest
@ActiveProfiles("test")
class ExposicaoDoActuatorTest {

    @Autowired
    private WebEndpointsSupplier endpoints;

    @Test
    @DisplayName("apenas health é servido — env, beans e heapdump não existem sobre HTTP")
    void apenasHealth() {
        var ids = endpoints.getEndpoints().stream()
                .map(e -> e.getEndpointId().toLowerCaseString())
                .toList();

        assertThat(ids).containsExactly("health");
        assertThat(ids).doesNotContain("env", "beans", "heapdump", "configprops", "loggers");
    }
}
