package br.com.relatorios.comum;

/**
 * Cinco valores. {@code EM_PROCESSAMENTO} é o inicial e o único não-terminal;
 * os demais são terminais e <strong>imutáveis</strong>.
 *
 * <p>Precedência no encerramento, da maior para a menor:
 * {@code ERRO} › {@code SEM_DADOS} › {@code ALERTA} › {@code SUCESSO}.
 *
 * <p>A fronteira entre {@code ALERTA} e {@code ERRO} é <em>ter completado</em>,
 * não a duração — é isso que sustenta a invariante {@code ALERTA ⇒ existe Artefato}.
 *
 * <p><strong>O container nunca grava {@code ERRO}.</strong> Ele sai com código ≠ 0 e
 * deixa a linha aberta; quem fecha é o {@code on_failure_callback} do Airflow, uma
 * única vez, ao esgotarem os retries.
 */
public enum StatusExecucao {
    EM_PROCESSAMENTO,
    SUCESSO,
    ALERTA,
    SEM_DADOS,
    ERRO;

    public boolean terminal() {
        return this != EM_PROCESSAMENTO;
    }

    /** {@code SUCESSO} e {@code ALERTA} têm Artefato com conteúdo; os demais, não. */
    public boolean temArtefato() {
        return this == SUCESSO || this == ALERTA;
    }
}
