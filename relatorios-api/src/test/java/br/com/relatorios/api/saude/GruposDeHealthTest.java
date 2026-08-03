package br.com.relatorios.api.saude;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.health.actuate.endpoint.HealthEndpointGroups;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Prova que os grupos existem e contêm o que o ticket 28 decidiu.
 *
 * <p><strong>Este teste nasceu de um erro real desta fase.</strong> A configuração dos
 * grupos foi escrita um nível acima do correto — {@code management.group} em vez de
 * {@code management.endpoint.health.group}. O Spring simplesmente <em>ignora</em> a chave
 * desconhecida: nenhum aviso, nenhuma falha no arranque. O {@code readiness} respondia
 * {@code UP} com o PostgreSQL derrubado, e só uma prova de ponta a ponta revelou.
 *
 * <p>Os outros testes desta fase não teriam pego: o de exposição verifica quais endpoints
 * são servidos, não o conteúdo dos grupos.
 */
@SpringBootTest
@ActiveProfiles("test")
class GruposDeHealthTest {

    @Autowired
    private HealthEndpointGroups grupos;

    @Test
    @DisplayName("os três grupos decididos existem")
    void gruposExistem() {
        assertThat(grupos.getNames()).contains("liveness", "readiness", "dependencias");
    }

    @Test
    @DisplayName("liveness NÃO inclui o banco — senão o container reinicia em laço na queda")
    void livenessNaoDependeDeNada() {
        var liveness = grupos.get("liveness");
        assertThat(liveness).isNotNull();
        assertThat(liveness.isMember("banco")).isFalse();
        assertThat(liveness.isMember("db")).isFalse();
        assertThat(liveness.isMember("livenessState")).isTrue();
    }

    @Test
    @DisplayName("readiness inclui o indicador AMORTECIDO, não o db cru")
    void readinessIncluiBancoAmortecido() {
        var readiness = grupos.get("readiness");
        assertThat(readiness).isNotNull();
        assertThat(readiness.isMember("readinessState")).isTrue();
        assertThat(readiness.isMember("banco")).isTrue();
        // O `db` cru fica de fora: ele reage à primeira falha e causaria vaivém.
        assertThat(readiness.isMember("db")).isFalse();
    }

    @Test
    @DisplayName("MinIO fora do readiness — degradação parcial preservada")
    void minioForaDoReadiness() {
        assertThat(grupos.get("readiness").isMember("minio")).isFalse();
    }
}
