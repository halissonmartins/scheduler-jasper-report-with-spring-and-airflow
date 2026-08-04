# 26 — Formato de erro e Correlation ID (inclusive no batch)

Type: grilling
Status: resolved
Blocked by: 01, 08

## Question

Qual o contrato de erro da API, e como o Correlation ID existe sempre?

O documento pede erros com horário, descrição, Correlation ID e "botão para copiar formato em JSON", inclusive no Swagger. E define o Correlation ID como o traceId do OpenTelemetry, propagado via MDC para busca no Graylog.

Decidir:

- **Separar contrato de affordance.** "Botão" é elemento de interface e não pertence ao OpenAPI. No contrato: o **schema** do erro (timestamp ISO-8601, código, descrição, correlationId). No frontend: o botão de copiar. Confirmar essa separação.
- **RFC 7807 (`application/problem+json`) ou schema próprio.** O 7807 é o candidato natural e tem suporte nativo no Spring — mas exige mapear os campos exigidos para `type`/`title`/`detail`/`instance` mais extensões.
- **Fallback do Correlation ID.** O SDK do OTel é desabilitado nos testes (regra do documento), logo não há span ativo, o MDC fica vazio, e qualquer cenário Gherkin que valide o Correlation ID na mensagem de erro falha. Decidir o fallback: aceitar um `traceparent` recebido no header, ou gerar um ID próprio quando não houver span. Escrever qual vence quando os dois existem.
- **Correlation ID no batch.** Um job disparado pelo Airflow não tem requisição HTTP de origem. Decidir como o `traceparent` injetado pelo Airflow (ticket 13) vira o span raiz do job, para correlacionar DAG run ↔ execução Spring Batch ↔ logs no Graylog. E o que acontece se o Airflow não injetar nada.
- **Catálogo de erros.** Os erros de negócio já conhecidos precisam de código estável: par duplicado rejeitado, item expirado (ticket 27), sem permissão para o relatório, exportação acima do limite (ticket 25), usuário pendente de vínculo (ticket 16).
- **O que nunca vaza.** Stack trace, SQL, nome de schema, credencial.

## Notas de research

- **Ticket 08**: `otel.sdk.disabled=true` é a ferramenta errada para os testes — e o
  `@SpringBootTest` já instala um Tracer no-op por conta própria. A alternativa levantada é manter
  o SDK ligado com `otel.*.exporter=none`: o MDC continua preenchido (logo o Correlation ID existe
  nos cenários Gherkin) e não há tráfego de rede nem dependência de Collector. Isso resolve
  diretamente a lacuna que este ticket precisa fechar, mas contraria a regra escrita na descrição
  inicial ("SDK do OpenTelemetry é desabilitado para que os testes não dependam de Collector") —
  a regra precisa ser reescrita aqui.

## Notas do ticket 02 (ciclo de vida)

Dois códigos entram no catálogo por decisão do ticket 02:

- **`EXECUCAO_SEM_DADOS`** — a Execução existe e está listada no drop-down, mas não gravou Artefato
  algum, então a exportação é recusada. Precisa ser distinto de "expirado" (ticket 27) e de "não
  encontrado": o relator tem de entender que a Coleta rodou e a origem não tinha linhas.
- **`EXECUCAO_NAO_CONCLUIDA`** (nome a definir) — pedido de exportação de Execução ainda em
  `EM_PROCESSAMENTO` ou encerrada em `ERRO`.

## Notas do ticket 14 (escopo do GERENTE)

- **As recusas da camada de mediação precisam de código estável**, porque elas são gravadas em
  `controle.auditoria_admin` com `resultado = RECUSADO` e `motivo_recusa` — não são só mensagem de
  tela. Candidatos: nome de role fora do padrão `REL_<SIGLA>_<NOME>`, Role que tentaria misturar
  Produtos, alvo fora da subárvore de grupos de relatório, e tentativa de operar sobre usuário que
  não é RELATOR.
- **O Correlation ID amarra os três registros** da mesma ação: a linha de auditoria, o log
  estruturado no Graylog e a resposta de erro devolvida ao GERENTE. Esse é o caso de uso concreto
  que justifica o fallback exigido neste ticket.
- **Nada de detalhe do Keycloak vaza** na resposta — corpo de erro da Admin API, nome de client,
  nome interno de permissão FGAP. Entra na lista de "o que nunca vaza".

## Notas do ticket 15 (autorização)

- **Existe uma classe de erro que este contrato nunca alcança.** Se o JWT crescer além do limite de
  cabeçalho, o Tomcat rejeita a requisição **antes** de qualquer filtro — sem MDC, sem Correlation
  ID, sem `@ControllerAdvice`, sem corpo padronizado. O ticket 15 decidiu não instalar guarda contra
  isso (risco aceito lá), então vale **documentar aqui** que a garantia "todo erro tem Correlation
  ID" tem essa exceção, em vez de deixá-la implícita.
- **Falha de autorização não distingue causa.** Com autorização saindo só da claim, "você não tem a
  Role de Relatório" e "seu acesso foi revogado há 2 minutos e o token ainda não expirou" produzem a
  mesma recusa. A mensagem precisa ser deliberadamente genérica — e a UI, orientar a refazer login,
  que é o que de fato resolve o segundo caso.

## Notas do ticket 16 (pendente de vínculo)

- **"Sem acesso a nenhum Relatório" não é erro** — é estado, e leva a uma página dedicada, não a uma
  resposta de erro. Vale a distinção explícita no catálogo, para que a listagem vazia não seja
  modelada como 403.
- **Um terceiro caso se junta aos dois acima**: aguardando vínculo e vinculado-sem-Relatório também
  produzem o mesmo resultado observável. São agora **quatro** situações distintas com uma saída só,
  o que reforça que o texto tem de ser genérico por decisão, não por descuido.
- **A vinculação é operação composta** (entrar no Grupo, sair do `PENDENTES`) e pode falhar pela
  metade. Isso merece código próprio no catálogo — o GERENTE precisa saber que a ação ficou incompleta,
  não receber sucesso silencioso.

## Notas do ticket 18 (desserialização)

- **Código próprio para divergência de integridade.** O SHA-256 do Artefato é conferido antes de
  desserializar; se não bater, a exportação é recusada. Isso não é "arquivo não encontrado" nem erro
  genérico — é sinal de adulteração ou corrupção, e precisa ser distinguível no catálogo, no log e na
  métrica. É a única defesa contra quem tem acesso apenas ao bucket (ADR 0002).
- **O que a mensagem não pode dizer**: nem o hash esperado, nem o obtido, nem a chave do objeto no
  repositório. Entra na lista de "o que nunca vaza", junto com stack trace e nome de schema.
- **Falha do `ObjectInputFilter`** é a outra recusa possível na leitura de um Artefato. Vale código
  distinto do de integridade: um significa "os bytes mudaram", o outro significa "os bytes trazem uma
  classe fora da allowlist" — investigações completamente diferentes.

## Notas do ticket 20 (idempotência e reprocessamento)

- **Duplicata barrada em T1** — a task `abrir_execucao` falha por violação do índice único parcial.
  Isso acontece **no Airflow**, não numa requisição HTTP, então o erro não passa pelo contrato desta
  API: ele aparece no log da task. Vale registrar essa fronteira aqui, porque é fácil supor que todo
  erro do sistema segue o formato padronizado.
- **Verbo indevido**: o ADMINISTRADOR pede `refazer` num par ocupado por `SUCESSO`, ou `reprocessar`
  num par já livre. Os dois merecem código próprio — o primeiro é "use reprocessar, e ele destrói",
  o segundo é "não há o que destruir". A API decide qual verbo é válido consultando o índice, então
  esses erros indicam UI dessincronizada, não usuário mal-intencionado.
- **`reprocessar` sem motivo** é recusa de validação, e o motivo vai para `controle.auditoria_admin`.

## Notas do ticket 23 (contrato do CSV)

- **A descrição do endpoint de exportação carrega uma regra de negócio**, não só o contrato técnico: o
  ticket 23 decidiu que o aviso sobre a divergência PDF × CSV vive na especificação e no **OpenAPI**,
  e não na UI. Isso torna o texto da descrição parte da decisão, não enfeite — ele precisa dizer que o
  CSV é o dataset da consulta principal e que totais e subtotais do relatório podem não ser
  reproduzíveis a partir dele.
- É um caso em que o OpenAPI é o **único** lugar onde a regra aparece para quem integra. Vale
  registrar aqui para que uma futura limpeza de descrições não a apague por parecer verbosa.

## Notas do ticket 25 (geração sob demanda)

Dois códigos novos, com naturezas bem diferentes:

- **Artefato acima do teto de exportação** → `409`. É condição **permanente** para aquele Artefato:
  tentar de novo não adianta, e a mensagem precisa deixar isso claro em vez de convidar a repetir.
  Como o limite não é imposto na Coleta (risco aceito no ticket 25), esse erro se repete todo dia para
  o mesmo Relatório.
- **Semáforo de exportações cheio** → `503` com `Retry-After`. É condição **transitória** e o oposto
  da anterior: repetir é exatamente o que se deve fazer. Confundir as duas na UI produz o pior de dois
  mundos — usuário insistindo no que nunca vai passar, e desistindo do que passaria.
- **Falha de integridade e recusa do `ObjectInputFilter`** (já registradas acima) acontecem **depois**
  de o semáforo ser adquirido. A liberação da vaga precisa acontecer em qualquer caminho de saída —
  vazar semáforo em caminho de erro esgota a capacidade da API sem nenhum sintoma além de `503`
  crescente.

## Answer

### O contrato: RFC 9457, não 7807

**Correção factual**: a RFC 7807 foi **obsoletada pela RFC 9457** (2023). E a documentação do Spring
da nossa versão diz textualmente que ele *"supports RFC 9457, 'Problem Details for HTTP APIs'"*, com
`ProblemDetail`, `ErrorResponse`, `ErrorResponseException` e `ResponseEntityExceptionHandler` prontos,
e o Jackson negociando `application/problem+json`.

Isso muda o peso da escolha, porque **schema próprio não é uma opção limpa**: o Spring já emite
`ProblemDetail` para os erros que ele mesmo gera — validação de `@Valid`, 404, 405, 415, JSON
malformado. Optar por schema próprio não substituiria isso; **acrescentaria um segundo formato** à
mesma API, a menos que se interceptasse cada um, um a um, e se acompanhasse isso a cada upgrade.

```
Content-Type: application/problem+json

{
  "type":          "urn:relatorios:erro:artefato-acima-do-limite",
  "title":         "Artefato acima do limite",
  "status":        409,
  "detail":        "Este relatório excede o tamanho máximo para exportação.",
  "instance":      "/execucoes/123/exportacao",
  "codigo":        "ARTEFATO_ACIMA_DO_LIMITE",
  "momento":       "2026-08-02T14:31:09Z",
  "correlationId": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

`type` é **URN não dereferenciável**: o `codigo` já carrega a identidade legível por máquina, e
publicar um catálogo dereferenciável criaria obrigação de hospedagem que apodrece.

### Contrato e affordance, separados — e mais limpo do que parecia

O "botão para copiar formato em JSON" é elemento de interface e não entra no OpenAPI. E a separação
sai de graça: como o corpo da resposta **já é JSON**, o botão copia a resposta verbatim. Não há
segunda serialização a definir nem a manter em sincronia.

### A regra do documento, reescrita

> ~~"SDK do OpenTelemetry é desabilitado para que os testes (JUnit/Cucumber/H2) não dependam de
> Collector nem gerem telemetria"~~
>
> **SDK do OpenTelemetry ligado em todo ambiente; nos testes, com exportador `none`.**

A preocupação original continua atendida — nenhum tráfego de rede, nenhuma dependência de Collector —
e o MDC permanece preenchido. **Correlation ID é sempre o traceId**: um conceito só, sem regra de
precedência entre identificadores concorrentes.

O argumento decisivo é de teste. Com o SDK desligado, não há span, o MDC fica vazio, e **todo cenário
Gherkin que valide o Correlation ID exercita o caminho de fallback** — o caminho que roda em produção
nunca é testado, e a divergência só aparece lá.

Rede de segurança: se o MDC estiver vazio quando o handler de erro rodar, gera-se um id e loga-se
`WARN`. Resposta de erro sem Correlation ID é pior que uma com id que não correlaciona com trace.

### Correlation ID no batch

O `traceparent` injetado pelo Airflow vira o span raiz do job por **código do Starter** — o Airflow não
propaga contexto para processos externos e a JVM não lê `TRACEPARENT` de variável de ambiente sozinha
(research 08). **Sem `traceparent` recebido, o Starter abre span novo e segue** — telemetria não é
dependência dura da Coleta.

**O Correlation ID nasce no container**, ao abrir o span raiz, e é gravado ao encerrar a Execução.

*Risco aceito.* Argumentei por gerá-lo em `abrir_execucao` (T1), antes do container, aproveitando que
essa task já existe e já grava a linha: um identificador só, existindo desde antes do container.
Consequência da decisão tomada: a linha aberta em T1 fica com `correlation_id` **nulo** até o container
gravar — e permanece nula para sempre se ele nunca subir (erro de pull, OOM no arranque), que é
justamente o caso que o ticket 02 criou T1 para tornar visível.

**Contenção**: o `dag_run_id` é gravado em T1 (ticket 04). Uma linha sem `correlation_id` continua
rastreável até a task do Airflow, cujo log tem a causa da falha de arranque. A correlação existe —
por outro caminho, e sem chegar ao Graylog.

### Catálogo da API

| Código | HTTP | Natureza |
|---|---|---|
| `ARTEFATO_ACIMA_DO_LIMITE` | 409 | permanente — repetir não adianta |
| `EXPORTACAO_INDISPONIVEL` | 503 + `Retry-After` | transitória — repetir é o certo |
| `ARTEFATO_INTEGRIDADE_DIVERGENTE` | 409 | SHA-256 não bate; sinal de adulteração |
| `ARTEFATO_CLASSE_NAO_PERMITIDA` | 409 | `ObjectInputFilter` recusou |
| `EXECUCAO_SEM_DADOS` | 409 | Execução existe, não gravou Artefato |
| `EXECUCAO_NAO_CONCLUIDA` | 409 | `EM_PROCESSAMENTO` ou `ERRO` |
| `ARTEFATO_EXPIRADO` | 410 | reservado ao ticket 27 |
| `SEM_PERMISSAO_PARA_RELATORIO` | 403 | genérico **por decisão** (ticket 15) |
| `ROLE_FORA_DO_PADRAO` | 422 | nome fora de `REL_<SIGLA>_<NOME>` |
| `ROLE_MISTURA_PRODUTOS` | 422 | Role atravessaria Produtos |
| `ALVO_FORA_DA_SUBARVORE` | 403 | mediação: alvo fora dos grupos de relatório |
| `USUARIO_NAO_E_RELATOR` | 422 | mediação sobre Perfil indevido |
| `VINCULACAO_INCOMPLETA` | 500 | entrou no Grupo, não saiu do `PENDENTES` |
| `VERBO_INDEVIDO_USE_REPROCESSAR` | 409 | `refazer` num par ocupado |
| `VERBO_INDEVIDO_NADA_A_DESTRUIR` | 409 | `reprocessar` num par já livre |
| `REPROCESSAMENTO_SEM_MOTIVO` | 422 | validação; o motivo vai para a auditoria |

**As duas primeiras são opostas e se confundem**: uma é permanente, a outra transitória. Trocá-las na
UI produz usuário insistindo no que nunca passa e desistindo do que passaria.

**`SEM_PERMISSAO_PARA_RELATORIO` é genérico por decisão, não por descuido.** Quatro situações
distintas produzem a mesma saída: sem Role de Relatório, acesso revogado com token ainda válido,
aguardando vínculo, e vinculado a Grupo sem Relatório algum. A UI orienta a refazer login, que é o que
resolve o segundo caso.

**"Sem acesso a nenhum Relatório" não é erro** — é estado, e leva à página dedicada do ticket 16. A
listagem vazia não é modelada como 403.

### Vocabulários separados entre batch e API

*Risco aceito.* Argumentei por catálogo único, porque alguns códigos são a **mesma natureza** de
problema detectada de dois lados — integridade do Artefato e recusa do filtro aparecem tanto na
gravação quanto na leitura. Decisão: o batch tem vocabulário próprio em `detalhe_erro.codigo`.

Consequência: duas tabelas na especificação, com risco de divergirem com o tempo, e quem investiga um
incidente que atravessa os dois lados precisa traduzir. A busca no Graylog passa a exigir saber de
antemão qual lado gerou o registro.

### O que nunca vaza

Stack trace, SQL, nome de schema, credencial, hash esperado ou obtido, chave do objeto no repositório,
corpo de erro da Admin API do Keycloak, nome de client e nome interno de permissão FGAP.

### A exceção à garantia "todo erro tem Correlation ID"

Se o JWT crescer além do limite de cabeçalho do Tomcat, a requisição é rejeitada **antes** de qualquer
filtro — sem MDC, sem Correlation ID, sem `@ControllerAdvice`, sem corpo padronizado. O ticket 15
decidiu não instalar guarda contra isso. Fica **documentado como exceção conhecida**, em vez de
implícito.

## Notas do ticket 45 (arquitetura Angular)

- **O catálogo continua sendo um só, e é o da API.** O front exibe o `detail` do `ProblemDetail` como
  veio e **não** mantém mapa próprio de `codigo` → mensagem: dois catálogos divergiriam no primeiro
  código novo, e o front não conhece o contexto (qual limite, de quanto, qual Relatório).
- **Consequência para a redação do `detail`**: ele é texto de tela, não log. Precisa ser escrito em
  pt-BR para o relator, com o número concreto quando houver um.
- **O front mapeia `codigo` para comportamento**, não para texto: `EXPORTACAO_INDISPONIVEL` é permanente
  e não oferece "tentar de novo"; `503` é transitório e oferece. Essa classificação precisa estar no
  catálogo, senão a tela a adivinha.
