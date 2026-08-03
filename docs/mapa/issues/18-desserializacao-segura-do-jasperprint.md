# 18 — Desserialização segura do JasperPrint vindo do repositório

Type: grilling
Status: resolved
Blocked by: 03, 10

## Question

Como a API REST desserializa um `.jrprint` do MinIO sem virar execução remota de código?

O trade-off aceito no documento diz: "o arquivo vem do módulo que está dentro do projeto, logo é confiável desserializar objeto Java de fonte". A análise comportamental aponta o furo: o arquivo vem do **bucket**, não do módulo. Quem escrever no bucket executa código na API REST. E criptografia em repouso está fora de escopo.

Decidir as mitigações e escrevê-las na spec:

- **Credenciais separadas.** Processadores só escrevem, API só lê — policy do MinIO, não convenção. Interage com o research 10.
- **Integridade.** Hash do objeto gravado nos metadados no momento da escrita e conferido antes de desserializar. Qual algoritmo, onde fica, e o que acontece quando não bate.
- **`ObjectInputFilter` (JEP 290).** Allowlist de `net.sf.jasperreports.*` (ou `com.jaspersoft.*`) e das classes de renderer necessárias (`BarbecueRendererImpl` e afins, citados no trade-off). Definir a allowlist concreta e como ela evolui quando um relatório novo usa um renderer novo.
- **Isolamento.** A desserialização acontece na JVM da API ou num processo/pod separado com heap limitado? Interage com o ticket 25.
- **Reafirmar ou revisar o trade-off.** O documento aceitou o risco com uma justificativa que não se sustenta. Decidir se o risco continua aceito com as mitigações acima, ou se algo muda (ex.: formato intermediário não-serializado).

## Notas de research

- **Ticket 05**: **CVE-2026-6009** — RCE de desserialização no JasperReports até a 7.0.6. O piso é
  **7.0.7**. Como desserializar `.jrprint` é o coração deste sistema, isso deixa de ser higiene de
  versão e vira controle de segurança de primeira ordem.
- **Ticket 05**: o trade-off da descrição inicial ("`serialVersionUID` não quebra entre versões
  porque todos os módulos usam a mesma versão do Jasper") está **certo pelo motivo errado**:
  `JRConstants.SERIAL_VERSION_UID` é a constante fixa `10200` em todas as versões, então o UID
  **não detecta** divergência — o erro é silencioso, não `InvalidClassException`. A versão única
  vira invariante a impor (enforcer no POM raiz) e a gravar nos metadados da Execução.
- **Ticket 10**: o expurgo por lifecycle nativo dispensa `s3:DeleteObject` em qualquer credencial
  da aplicação, o que estreita bastante a policy proposta aqui. Ressalva do research: a separação
  escrita/leitura **não** protege contra um processador comprometido.

## Notas do ticket 03 (chave e data)

- **O raio de explosão do processador comprometido continua sendo o bucket inteiro.** O layout ficou
  `{yyyy-MM-dd}/{SIGLA}/{CODIGO}/`, com a data como primeiro componente. Como policies do MinIO
  operam por prefixo (`arn:aws:s3:::bucket/prefixo/*`) e **wildcard no meio do prefixo não existe**,
  não há como restringir cada processador ao próprio Produto — `bucket/*/POUPANCA/*` não funciona.
  Foi risco aceito no ticket 03, com o argumento contrário registrado lá.
- **Consequência direta para este ticket**: o hash SHA-256 conferido antes de desserializar e o
  `ObjectInputFilter` (JEP 290) deixam de ser defesa em profundidade e passam a ser as **únicas**
  defesas nessa fronteira. Não há segunda camada de policy atrás delas.
- **A chave é determinística e derivável** de (data, código), e o schema de controle grava a chave
  completa. A API busca por chave conhecida, nunca por listagem — o research 10 já havia omitido
  `s3:ListBucket` da credencial da API de propósito.

## Answer

Registrado também no [ADR 0002](../../adr/0002-desserializacao-java-do-jasperprint.md), porque é caro
de reverter e um leitor futuro vai perguntar por quê.

### O trade-off da descrição inicial: reafirmado, com a justificativa corrigida

O documento aceitou o risco dizendo que "o arquivo vem do módulo que está dentro do projeto, logo é
confiável". **Isso está errado** — o arquivo vem do bucket. A decisão de manter a serialização Java
fica de pé, mas por outra razão, registrada abaixo.

Foi considerada e recusada a alternativa que **dissolveria** a classe de ameaça em vez de mitigá-la:
o JasperReports persiste `JasperPrint` em **XML** (`.jrpxml` — o README do projeto mostra
`mvn exec:java@view -Dexec.args=target/reports/I18nReport.jrpxml`), e carregar XML não executa código.
Custos que pesaram contra: arquivos muito maiores, renderers precisariam ser rasterizados no momento
da gravação (o trade-off do documento exige que `BarbecueRendererImpl` e afins viajem), a fidelidade
do ida-e-volta **não foi confirmada na documentação**, e mudaria os tickets 03, 21, 22 e 27.

### Formato: `.jrprint` serializado

Mantido. As defesas ficam sendo o piso de versão, os limites de recurso e o hash.

### Allowlist do `ObjectInputFilter`: por pacote

`net.sf.jasperreports.**` e `java.**` liberados, `!*` negando o resto, mais os limites do JEP 290
(`maxdepth`, `maxrefs`, `maxbytes`, `maxarray`). Um Relatório novo com renderer novo funciona sem
revisão de lista.

*Risco aceito.* Argumentei por allowlist de classes específicas, porque o **CVE-2026-6009 é prova
direta**, não analogia: foi um RCE de desserialização cujo gadget estava **dentro** de
`net.sf.jasperreports.*` — a allowlist por pacote não o teria barrado. Decisão: por pacote, aceitando
que a proteção contra gadget interno passa a ser a versão do Jasper.

### Isolamento: nenhum

A desserialização e a exportação rodam na JVM da API, como a descrição inicial sugere.

*Risco aceito.* Argumentei por processo isolado — heap próprio, sem credencial de banco, sem
credencial do MinIO e sem saída de rede — porque RCE ali cairia num lugar sem nada a alcançar, e
porque conteria junto o OOM que a análise comportamental aponta como o ponto de ruptura da API. Um
subprocesso não contraria a regra de que "a geração e download devem ser feitos pelo módulo de API
REST": é detalhe de implementação daquele módulo. Decisão: mesma JVM. Consequência: RCA na API
alcança a credencial do banco de controle, a de leitura do MinIO e a rede interna; e uma exportação
grande demais derruba a API para todos.

### Versão do JasperReports: piso documentado, atualização manual

Piso **7.0.7** (CVE-2026-6009), registrado na especificação com o motivo. O enforcer de versão única
do ticket 05 continua valendo, porque `JRConstants.SERIAL_VERSION_UID` é a constante fixa `10200` em
todas as versões e divergência falha em **silêncio**.

*Risco aceito.* Argumentei por gate no CI abaixo do piso mais Dependabot — nativo no GitHub Actions
que a stack já usa —, porque esta virou a defesa primária desta fronteira. Decisão: manual.

### Derivado, não perguntado

- **Credenciais separadas** (research 10): processadores só escrevem, API só lê. Ninguém tem
  `s3:DeleteObject`, porque o expurgo é lifecycle nativo. A API também não tem `s3:ListBucket` — ela
  busca por chave conhecida, determinística (ticket 03) e gravada por extenso (ticket 04).
- **SHA-256 conferido antes de desserializar.** Divergência recusa a exportação, com código próprio
  no catálogo do ticket 26, log com Correlation ID e métrica. É a única defesa contra quem tem acesso
  apenas ao bucket.

### O risco residual, consolidado

As cinco escolhas se compõem, e o efeito só é visível quando lidas juntas:

| Camada | Estado |
|---|---|
| Formato | serializado — classe de ameaça viva |
| Allowlist | por pacote — não barra gadget interno ao Jasper |
| Isolamento | nenhum — RCE alcança banco, MinIO e rede interna |
| SHA-256 | não cobre processador comprometido (ele escreve `controle.artefato`) |
| Prefixo por Produto no MinIO | inexistente (risco aceito no ticket 03) |

**Sobra uma defesa efetiva: manter o JasperReports atualizado — e isso é manual.**

O risco continua **proporcional na origem**: o atacante relevante é quem compromete um processador,
e esse já tem a base transacional de um Produto inteiro. RCE na API é escalada modesta a partir daí,
não o salto de "nada" para "tudo" que a análise comportamental sugere. É esse o argumento que
sustenta o conjunto — não a justificativa original do documento, que era falsa.
