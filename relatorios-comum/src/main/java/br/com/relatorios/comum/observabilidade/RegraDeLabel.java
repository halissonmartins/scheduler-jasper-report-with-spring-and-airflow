package br.com.relatorios.comum.observabilidade;

import java.util.Set;

/**
 * <strong>Um label só é permitido se seu conjunto de valores for limitado por cadastro,
 * nunca por uso.</strong>
 *
 * <p>Esta classe existe porque a guarda de cardinalidade ficou <em>documental</em>: não há
 * nada no build que a imponha. Então ela mora aqui, onde as métricas nascem, e não só na
 * especificação.
 *
 * <p>A conta que desarma o medo errado: 10 Códigos × 5 status ≈ 50 séries por métrica, e
 * alguns milhares no sistema todo. O Prometheus lida com milhões. Cruzar Código com formato
 * e status <em>não</em> é o problema — o problema é label que cresce com o uso.
 */
public final class RegraDeLabel {

    /** Limitados por cadastro. Crescem quando alguém cadastra algo, não quando alguém usa. */
    public static final Set<String> PERMITIDOS = Set.of(
            "produto", "codigo_relatorio", "status", "formato", "tipo",
            "codigo", "origem_encerramento", "motivo", "desfecho", "tabela");

    /** Crescem com o uso. Vivem em log e trace, nunca em métrica. */
    public static final Set<String> PROIBIDOS = Set.of(
            "data_referencia", "usuario", "correlation_id", "dag_run_id", "chave_artefato");

    private RegraDeLabel() {
    }

    public static boolean permitido(String label) {
        return PERMITIDOS.contains(label);
    }
}
