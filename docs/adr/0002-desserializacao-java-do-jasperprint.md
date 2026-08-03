# O Artefato continua sendo `JasperPrint` serializado em Java, com filtro por pacote e sem isolamento

A API REST desserializa objetos Java (`.jrprint`) vindos de um bucket S3. A descrição inicial
aceitou esse risco com a justificativa de que "o arquivo vem do módulo que está dentro do projeto,
logo é confiável desserializar objeto Java de fonte". **A justificativa é falsa**: o arquivo vem do
*bucket*, não do módulo. Quem escreve no bucket executa código na API.

Decidimos **manter** a serialização Java, com allowlist de desserialização no nível de **pacote**,
**sem** isolamento em processo separado, e com atualização **manual** da biblioteca. A justificativa
correta é outra, e está na última seção.

## A alternativa que foi recusada

O JasperReports persiste `JasperPrint` em **XML** (`.jrpxml`) além do formato serializado — o README
do projeto documenta `mvn exec:java@view -Dexec.args=target/reports/I18nReport.jrpxml`. Carregar XML
não invoca desserialização Java, o que **eliminaria a classe de ameaça** em vez de mitigá-la.

Pesaram contra: arquivos várias vezes maiores; renderers precisariam ser rasterizados na gravação,
enquanto o trade-off da descrição inicial exige que `BarbecueRendererImpl` e afins viajem como
objetos; a fidelidade do ida-e-volta não foi confirmada em documentação; e a mudança alcançaria o
layout da chave, o contrato do Starter, a questão paginado × não paginado e a retenção.

## O que ficou no lugar

- **Piso de versão 7.0.7**, por causa do CVE-2026-6009 (RCE de desserialização no próprio
  JasperReports). Atualização manual, sem gate no CI e sem robô de dependência.
- **`ObjectInputFilter` (JEP 290) por pacote** — `net.sf.jasperreports.**`, `java.**`, `!*` — mais os
  limites `maxdepth`, `maxrefs`, `maxbytes` e `maxarray`.
- **SHA-256** gravado na escrita e conferido antes de desserializar.
- **Credenciais separadas** no MinIO: processadores só escrevem, API só lê, ninguém apaga.
- **Enforcer de versão única** do Jasper no POM raiz, porque `JRConstants.SERIAL_VERSION_UID` é a
  constante fixa `10200` em todas as versões e divergência falha em silêncio, não com
  `InvalidClassException`.

## Consequências

- **A allowlist por pacote não teria barrado o CVE-2026-6009**, cujo gadget estava dentro de
  `net.sf.jasperreports.*`. A proteção contra gadget interno ao Jasper é a versão da biblioteca.
- **O SHA-256 não cobre processador comprometido.** Os processadores têm escrita em
  `controle.artefato`, então um processador comprometido grava o payload e o hash correspondente. O
  hash protege contra quem tem acesso apenas ao bucket.
- **Sem isolamento, RCE na API alcança** a credencial do banco de controle, a credencial de leitura
  do MinIO e a rede interna do Compose.
- **O OOM não tem contenção.** Desserializar e exportar um `JasperPrint` grande na JVM da API derruba
  a API para todos os usuários. Limites de tamanho e de concorrência na exportação passam a ser a
  única proteção contra isso.
- **Não há prefixo por Produto no MinIO** (decidido no ADR do layout de chave / ticket 03), então
  qualquer processador pode escrever qualquer Artefato.
- **Manter o JasperReports atualizado deixou de ser higiene de dependência e virou o controle de
  segurança primário desta fronteira.** Um CVE novo no Jasper não gera aviso automático neste
  projeto.

## Por que o risco é aceitável

O atacante relevante não é um estranho: é quem compromete um módulo processador ou suas credenciais.
Esse atacante **já tem leitura da base transacional de um Produto inteiro** — dados de clientes,
contas, empréstimos. Execução remota de código na API REST, a partir dali, é escalada modesta, não o
salto de "nada" para "tudo".

É esse o argumento que sustenta o conjunto de decisões acima. Se a premissa mudar — se os
processadores deixarem de ler bases transacionais sensíveis, ou se a API passar a ter acesso a algo
que os processadores não têm — **esta decisão precisa ser revisitada**, começando pelo isolamento em
processo separado, que é a mitigação de melhor relação custo-benefício entre as recusadas.
