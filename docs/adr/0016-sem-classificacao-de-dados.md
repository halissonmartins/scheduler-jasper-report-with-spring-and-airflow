# Sem classificação de dados nem mascaramento

Não existe campo de classificação de sensibilidade no Cadastro nem mascaramento de campos no conteúdo gerado. O acesso ao dado é controlado exclusivamente pela Role de Relatório: quem tem a role vê o dado completo.

Registrado porque o contexto sugeriria o contrário — os Produtos (POUPANCA, CLIENTE, CONTACORRENTE, EMPRESTIMO, CONSORCIO) carregam dado pessoal e financeiro sob LGPD, e a aplicação está exposta à internet (ADR-0010). Um leitor futuro presumiria que houve classificação e não a encontraria.

## Considered Options

- **Classificação por Relatório com regras de manuseio** — recomendada e recusada. Traria: proibição de payload de linha em log, exceção e telemetria; criptografia em repouso; dado sintético em ambientes não-produtivos.
- **Mascaramento por role dentro do conteúdo** — recusada; dobraria a matriz de teste e exigiria dois modos de renderização em cada template Jasper.

## Consequências (riscos aceitos)

- Nada impede que uma linha de relatório com CPF apareça em log de aplicação, mensagem de exceção ou telemetria OTLP — e log normalmente não tem o mesmo controle de acesso que o banco.
- Não há decisão de criptografia em repouso para os volumes de MongoDB e PostgreSQL.
- Cópia de dados de produção para ambientes não-produtivos permanece sem regra.
- A exposição de LGPD decorrente é assumida pela organização, não mitigada pelo desenho.
