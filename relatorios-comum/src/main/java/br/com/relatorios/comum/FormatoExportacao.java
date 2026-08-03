package br.com.relatorios.comum;

/**
 * O CSV é diferente dos outros três, e a diferença é de arquitetura, não de detalhe:
 * ele não passa pelo Jasper, já está gravado, <strong>não desserializa nada</strong> e
 * por isso não consome o semáforo de exportação.
 */
public enum FormatoExportacao {
    PDF(true),
    XLSX(true),
    DOCX(true),
    CSV(false);

    private final boolean desserializa;

    FormatoExportacao(boolean desserializa) {
        this.desserializa = desserializa;
    }

    /** {@code true} quando a exportação precisa desserializar o {@code .jrprint}. */
    public boolean desserializa() {
        return desserializa;
    }
}
