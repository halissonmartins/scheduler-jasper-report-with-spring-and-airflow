package br.com.relatorios.processador;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Reúne os beans de {@link DefinicaoRelatorio} do módulo. É a fonte do
 * {@code --publicar-inventario} e do despacho por Código.
 */
public class RegistroDeRelatorios {

    private final Map<String, DefinicaoRelatorio> porCodigo;

    public RegistroDeRelatorios(List<DefinicaoRelatorio> definicoes) {
        this.porCodigo = definicoes.stream()
                .collect(Collectors.toMap(DefinicaoRelatorio::codigo, Function.identity()));
    }

    public DefinicaoRelatorio exigir(String codigo) {
        DefinicaoRelatorio d = porCodigo.get(codigo);
        if (d == null) {
            throw new IllegalArgumentException(
                    "Nenhuma DefinicaoRelatorio para o código " + codigo
                    + ". Conhecidos neste módulo: " + porCodigo.keySet());
        }
        return d;
    }

    /** O inventário publicado no bootstrap é exatamente isto. */
    public List<DefinicaoRelatorio> inventario() {
        return List.copyOf(porCodigo.values());
    }
}
