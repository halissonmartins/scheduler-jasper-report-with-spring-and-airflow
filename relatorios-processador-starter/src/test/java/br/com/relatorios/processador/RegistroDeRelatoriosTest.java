package br.com.relatorios.processador;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RegistroDeRelatoriosTest {

    private static DefinicaoRelatorio definicao(String codigo) {
        return new DefinicaoRelatorio() {
            @Override public String codigo() { return codigo; }
            @Override public String jrxml() { return "jasper/x.jrxml"; }
            @Override public String consulta() { return "select 1"; }
            @Override public Map<String, String> colunas() { return Map.of("a", "A"); }
        };
    }

    @Test
    @DisplayName("o inventário é a enumeração dos beans — declarar e poder executar é a mesma coisa")
    void inventarioEhOsBeans() {
        var registro = new RegistroDeRelatorios(
                List.of(definicao("POUPANCA-0001"), definicao("POUPANCA-0002")));

        assertThat(registro.inventario())
                .extracting(DefinicaoRelatorio::codigo)
                .containsExactlyInAnyOrder("POUPANCA-0001", "POUPANCA-0002");
    }

    @Test
    @DisplayName("Código sem bean falha claro, dizendo o que o módulo conhece")
    void codigoDesconhecidoFalhaClaro() {
        var registro = new RegistroDeRelatorios(List.of(definicao("POUPANCA-0001")));

        assertThatThrownBy(() -> registro.exigir("POUPANCA-0009"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("POUPANCA-0009")
                .hasMessageContaining("POUPANCA-0001");
    }
}
