package br.com.relatorios.api.saude;

import java.sql.Connection;
import java.util.concurrent.atomic.AtomicInteger;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;

/**
 * O PostgreSQL visto pelo {@code readiness} — <strong>com amortecimento</strong>.
 *
 * <p>Sem isto, o risco que a inclusão do banco no {@code readiness} cria é o oposto do
 * problema que ela resolve: uma consulta de validação falha por dois segundos, o indicador
 * cai, a instância sai do balanceamento, a verificação seguinte passa, e ela volta. Com
 * poucas instâncias, esse vaivém é mais disruptivo que a falha original.
 *
 * <p><strong>Assimétrico de propósito</strong>: sair do ar é caro, voltar é barato. DOWN só
 * após N falhas consecutivas; UP na primeira que passar.
 *
 * <p><strong>O amortecimento precisa morar aqui, não no Compose.</strong> O {@code retries}
 * do healthcheck do Compose amortece só o Compose — o health check do Traefik reage à
 * primeira falha, e é ele que decide o balanceamento.
 *
 * <p>Note que este indicador é distinto do {@code db} auto-configurado pelo Spring, que
 * reporta o estado <strong>cru</strong> e alimenta o grupo de dependências consumido por
 * Prometheus e Grafana. Um serve para observar; o outro, para decidir tráfego.
 */
@Component("banco")
public class IndicadorDeBancoAmortecido implements HealthIndicator {

    private final DataSource dataSource;
    private final int falhasParaCair;
    private final int timeoutSegundos;
    private final AtomicInteger falhasSeguidas = new AtomicInteger();

    public IndicadorDeBancoAmortecido(
            DataSource dataSource,
            @Value("${relatorios.saude.banco.falhas-para-cair:3}") int falhasParaCair,
            @Value("${relatorios.saude.banco.timeout-segundos:2}") int timeoutSegundos) {
        this.dataSource = dataSource;
        this.falhasParaCair = falhasParaCair;
        this.timeoutSegundos = timeoutSegundos;
    }

    @Override
    public Health health() {
        if (validou()) {
            falhasSeguidas.set(0);
            return Health.up().withDetail("falhasSeguidas", 0).build();
        }

        int seguidas = falhasSeguidas.incrementAndGet();
        if (seguidas < falhasParaCair) {
            // Ainda UP: um soluço não tira a instância do ar.
            return Health.up()
                    .withDetail("falhasSeguidas", seguidas)
                    .withDetail("falhasParaCair", falhasParaCair)
                    .build();
        }
        return Health.down()
                .withDetail("falhasSeguidas", seguidas)
                .withDetail("falhasParaCair", falhasParaCair)
                .build();
    }

    private boolean validou() {
        try (Connection c = dataSource.getConnection()) {
            return c.isValid(timeoutSegundos);
        } catch (Exception e) {
            return false;
        }
    }

    int falhasSeguidasAtuais() {
        return falhasSeguidas.get();
    }
}
