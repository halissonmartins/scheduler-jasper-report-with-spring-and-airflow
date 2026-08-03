package br.com.relatorios.processador;

import java.util.Map;
import java.util.Optional;

/**
 * A SPI que cada módulo processador implementa — <strong>um bean por Relatório</strong>.
 *
 * <p>A propriedade que decidiu esta forma, contra um arquivo de registro: <strong>o
 * inventário é a enumeração destes beans</strong>. Um arquivo poderia listar um Relatório
 * cuja classe não existe, ou omitir uma que existe, e o inventário publicado herdaria a
 * divergência. Com beans, declarar e poder executar são a mesma coisa.
 *
 * <p>O Starter seleciona pelo {@code CODIGO_RELATORIO} recebido na entrada e falha de forma
 * clara se não houver bean correspondente.
 */
public interface DefinicaoRelatorio {

    /** Formato {@code SIGLA-NNNN}. Permanente — nunca muda. */
    String codigo();

    /** Recurso no classpath do próprio módulo, sob {@code jasper/}. */
    String jrxml();

    /**
     * SQL da consulta principal. Precisa funcionar com cursor, respeitando as quatro
     * condições do pgjdbc — autocommit desligado, {@code TYPE_FORWARD_ONLY}, statement
     * único e {@code fetchSize > 0}. Faltando qualquer uma, o driver <strong>degrada em
     * silêncio</strong> e bufferiza o {@code ResultSet} inteiro.
     */
    String consulta();

    /**
     * Colunas do dataset, em ordem, com o rótulo que vai ao cabeçalho do CSV.
     *
     * <p>Os rótulos vêm daqui e <strong>não</strong> do JRXML: cabeçalho de coluna lá pode
     * ser expressão, texto estilizado ou imagem, e a extração seria frágil de um jeito que
     * só falha em relatório específico.
     */
    Map<String, String> colunas();

    /**
     * Sugestão, não verdade. O tempo estimado é dado de cadastro, sob o ADMINISTRADOR,
     * porque depende do volume <em>daquele ambiente</em> e muda sem que o código mude.
     * Este valor é publicado com o inventário e a tela de cadastro o oferece
     * pré-preenchido — resolvendo o Relatório recém-criado, que não tem histórico.
     */
    default Optional<Integer> tempoEstimadoSugeridoSegundos() {
        return Optional.empty();
    }
}
