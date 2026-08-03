package br.com.relatorios.api.saude;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;

import java.sql.Connection;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.health.contributor.Status;

/**
 * O amortecimento é o que torna administrável o risco aceito no ticket 28 — e é lógica
 * temporal, do tipo que passa despercebida numa refatoração. O sintoma da regressão é
 * vaivém de instância em produção, não teste vermelho: daí este teste existir.
 */
class IndicadorDeBancoAmortecidoTest {

    private static DataSource dataSourceQueFalha() throws SQLException {
        DataSource ds = mock(DataSource.class);
        given(ds.getConnection()).willThrow(new SQLException("banco fora"));
        return ds;
    }

    private static DataSource dataSourceQueResponde() throws SQLException {
        DataSource ds = mock(DataSource.class);
        Connection c = mock(Connection.class);
        given(ds.getConnection()).willReturn(c);
        given(c.isValid(anyInt())).willReturn(true);
        return ds;
    }

    @Test
    @DisplayName("uma falha isolada NÃO derruba o readiness — é o soluço que não deve tirar do ar")
    void umaFalhaNaoDerruba() throws Exception {
        var indicador = new IndicadorDeBancoAmortecido(dataSourceQueFalha(), 3, 2);

        assertThat(indicador.health().getStatus()).isEqualTo(Status.UP);
    }

    @Test
    @DisplayName("N falhas consecutivas derrubam, e nem uma a menos")
    void nFalhasDerrubam() throws Exception {
        var indicador = new IndicadorDeBancoAmortecido(dataSourceQueFalha(), 3, 2);

        assertThat(indicador.health().getStatus()).isEqualTo(Status.UP);   // 1
        assertThat(indicador.health().getStatus()).isEqualTo(Status.UP);   // 2
        assertThat(indicador.health().getStatus()).isEqualTo(Status.DOWN); // 3
    }

    @Test
    @DisplayName("volta a UP na PRIMEIRA que passar — sair do ar é caro, voltar é barato")
    void voltaNaPrimeiraQuePassa() throws Exception {
        DataSource falha = dataSourceQueFalha();
        var indicador = new IndicadorDeBancoAmortecido(falha, 2, 2);

        indicador.health();
        assertThat(indicador.health().getStatus()).isEqualTo(Status.DOWN);

        var recuperado = new IndicadorDeBancoAmortecido(dataSourceQueResponde(), 2, 2);
        assertThat(recuperado.health().getStatus()).isEqualTo(Status.UP);
        assertThat(recuperado.falhasSeguidasAtuais()).isZero();
    }
}
