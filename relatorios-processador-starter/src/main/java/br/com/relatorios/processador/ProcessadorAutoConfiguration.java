package br.com.relatorios.processador;

import java.util.List;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Bean;

/**
 * Descobre os beans de {@link DefinicaoRelatorio} do módulo.
 *
 * <p><strong>Não configura JobRepository.</strong> O Spring Batch 6 usa
 * {@code ResourcelessJobRepository} por padrão — sem {@code DataSource}, sem tabelas
 * {@code BATCH_*}, sem instância Flyway própria. A Execução do schema de controle é a
 * única fonte de verdade do que rodou.
 *
 * <p><strong>Consequência que o Starter precisa impor, não delegar ao módulo:</strong> o
 * {@code ResourcelessJobRepository} não é thread-safe, então os steps são obrigatoriamente
 * single-thread — sem {@code TaskExecutor} e sem particionamento. Um módulo que adicionasse
 * paralelismo corromperia metadados em silêncio.
 */
@AutoConfiguration
public class ProcessadorAutoConfiguration {

    @Bean
    public RegistroDeRelatorios registroDeRelatorios(List<DefinicaoRelatorio> definicoes) {
        return new RegistroDeRelatorios(definicoes);
    }
}
