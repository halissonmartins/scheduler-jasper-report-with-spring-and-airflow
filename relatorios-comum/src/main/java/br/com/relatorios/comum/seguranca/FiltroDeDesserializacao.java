package br.com.relatorios.comum.seguranca;

import java.io.ObjectInputFilter;

/**
 * Filtro JEP 290 aplicado antes de desserializar um {@code .jrprint} vindo do repositório.
 *
 * <p><strong>Esta é uma das duas únicas defesas nessa fronteira</strong> — a outra é o
 * SHA-256 conferido antes da leitura. Não há isolamento em processo separado e não há
 * policy por Produto no MinIO; as duas alternativas foram consideradas e recusadas
 * (ADR 0002).
 *
 * <p>O grão é <strong>pacote</strong>, não classe. Consequência registrada: o
 * CVE-2026-6009 foi um RCE cujo gadget estava <em>dentro</em> de
 * {@code net.sf.jasperreports.*} — uma allowlist neste grão não o teria barrado. A
 * proteção contra gadget interno é manter a biblioteca atualizada, e isso é manual.
 */
public final class FiltroDeDesserializacao {

    private static final String PADRAO = String.join(";",
            "maxdepth=64",
            "maxrefs=100000",
            "maxbytes=104857600",
            "maxarray=1000000",
            "net.sf.jasperreports.**",
            "java.**",
            "!*");

    private FiltroDeDesserializacao() {
    }

    public static ObjectInputFilter padrao() {
        return ObjectInputFilter.Config.createFilter(PADRAO);
    }
}
