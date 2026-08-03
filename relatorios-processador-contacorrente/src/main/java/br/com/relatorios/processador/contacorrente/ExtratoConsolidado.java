package br.com.relatorios.processador.contacorrente;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Component;

import br.com.relatorios.processador.DefinicaoRelatorio;

/** Esqueleto — a consulta e o JRXML de verdade vêm com os modelos de dados deste Produto. */
@Component
public class ExtratoConsolidado implements DefinicaoRelatorio {

    @Override
    public String codigo() {
        return "CONTACORRENTE-0001";
    }

    @Override
    public String jrxml() {
        return "jasper/contacorrente-0001.jrxml";
    }

    @Override
    public String consulta() {
        return "select 1 as placeholder";
    }

    @Override
    public Map<String, String> colunas() {
        Map<String, String> c = new LinkedHashMap<>();
        c.put("placeholder", "Placeholder");
        return c;
    }

    @Override
    public Optional<Integer> tempoEstimadoSugeridoSegundos() {
        return Optional.of(60);
    }
}
