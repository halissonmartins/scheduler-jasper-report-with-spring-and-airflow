package br.com.relatorios.processador.consorcio;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Dois modos, uma imagem (ticket 19): rodar uma Coleta e {@code --publicar-inventario}.
 *
 * <p><strong>{@code System.exit(SpringApplication.exit(...))} é requisito de contrato</strong>,
 * não detalhe. Sem ele o {@code ExitCodeGenerator} não age, um job Batch falho sai com
 * código 0, e o Airflow marca {@code success} num job que falhou — o pior modo de falha
 * possível, porque tudo parece verde.
 */
@SpringBootApplication
public class Aplicacao {

    public static void main(String[] args) {
        System.exit(SpringApplication.exit(SpringApplication.run(Aplicacao.class, args)));
    }
}
