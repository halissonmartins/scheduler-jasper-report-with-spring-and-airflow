# 29 — Métricas, labels e guarda de cardinalidade

Type: grilling
Status: resolved
Blocked by: 08

## Question

Quais métricas o sistema emite, e com quais labels?

O documento pede que, sempre que possível, as métricas usem os labels nome do produto e código do relatório. A análise comportamental confirma que isso é adequado (dezenas de séries) mas alerta: incluir data ou usuário nas mesmas métricas explode a cardinalidade no Prometheus.

Decidir e escrever o catálogo:

- **Métricas da Coleta**: duração da execução, linhas lidas, tamanho dos artefatos, contagem por status, quantas passaram do tempo estimado, quantas sofreram timeout duro.
- **Métricas da API**: latência e contagem por endpoint, duração de exportação por formato, exportações rejeitadas por limite, downloads, downloads de item expirado, falhas de autorização.
- **Labels permitidos** por métrica, e a regra explícita: **nunca** data de referência, nunca identificador de usuário, nunca Correlation ID como label. Esses vivem em log e trace, não em métrica.
- **Guarda de cardinalidade**: teto estimado de séries (5 produtos × 2 relatórios × formatos × status) e o que impede o crescimento quando produtos novos entrarem.
- **Painéis no Grafana**: quais perguntas operacionais os painéis respondem (uma coleta atrasou? uma exportação está lenta? quantos relatórios falharam hoje?).
- **Alertas**: quais condições merecem alerta, e para quem.

## Notas do ticket 02 (ciclo de vida)

Métricas que o ciclo de vida decidido no ticket 02 exige:

- **`execucao_encerramento_perdido`** — incrementada quando uma escrita terminal casa zero linhas,
  ou seja, alguém já havia encerrado a Execução. É o sinal de que a varredura e o container
  disputaram a mesma linha. Como o `LIMITE_ORFA` é global (risco aceito no ticket 02), essa métrica
  é o que torna o risco visível — merece alerta, não só painel.
- **Contagem por status com cinco valores**, incluindo `SEM_DADOS`. Uma coleta que passa a devolver
  zero linhas todo dia é falha de origem disfarçada de sucesso.
- **Execuções fechadas pela varredura**, separadas das fechadas pelo callback e pelo próprio
  container — o label vem da origem gravada em `detalhe_erro` (ticket 04). Toda linha fechada por
  varredura é infraestrutura que falhou sem avisar. Interage com o ticket 36.
- **Confirmar que "atrasada" não vira métrica própria**: é derivado do relógio, então o que se mede
  é a duração da Execução contra o tempo estimado, no encerramento.

## Notas do ticket 24 (tolerância do tempo estimado)

- **A métrica de `ALERTA` é o mecanismo de aviso, não um enfeite.** O ticket 24 decidiu que `ALERTA`
  **não** notifica ninguém pela aplicação — quem transforma isso em aviso é o **Grafana**. Isso
  promove a métrica por Código de Relatório a controle operacional, e o alerta do Grafana precisa ser
  por **padrão** ("cinco dias seguidos"), não por ocorrência, senão reproduz o ruído que o ticket 24
  existia para evitar.
- **A duração medida é `fim − inicio_processamento`**, não `fim − inicio`. A métrica de duração
  precisa usar a mesma janela que o limiar de `ALERTA`, senão painel e status discordam.
- **Vale medir também `inicio_processamento − inicio`** — o custo de partida do container. É o número
  que justifica os 120 s de folga do `execution_timeout` e o único jeito de perceber que pull de
  imagem está degradando.
- **Contagem de tentativas por Execução**: com retry reusando a linha, três tentativas ficam
  invisíveis num contador de Execuções. Sem essa métrica, uma origem instável que passa sempre na
  terceira tentativa parece perfeitamente saudável.

## Notas do ticket 25 (geração sob demanda)

- **A métrica de tamanho de Artefato virou controle, não observação.** O ticket 25 decidiu não impor
  teto na Coleta (risco aceito), e a contenção é justamente esta: `tamanho_artefato_bytes` com label
  de Código de Relatório, e alerta no Grafana ao ultrapassar o teto de exportação. Sem ela, o
  ADMINISTRADOR só descobre pelo chamado do relator.
- **Métricas do semáforo de exportação** — ocupação, tempo de espera e recusas por `503`. São o único
  sinal de que a API está no limite de capacidade, já que não há isolamento (ADR 0002) e o modo de
  falha seguinte é OOM.
- **Duração da exportação por formato**, e ela não é simétrica: PDF, XLSX e DOCX desserializam; o CSV
  não. Medi-los juntos esconde exatamente a diferença que importa para dimensionar heap.
- **Cuidado de cardinalidade**: o Código de Relatório como label continua adequado (dezenas de
  séries), mas cruzar Código × formato × status multiplica. Vale decidir quais métricas carregam
  qual conjunto de labels em vez de aplicar o mesmo a todas.

## Notas do ticket 26 (formato de erro)

- **O `codigo` do catálogo é um bom label; o Correlation ID não é.** O catálogo é fechado e pequeno
  (dezesseis códigos hoje), então contar erros por `codigo` é seguro. O Correlation ID é único por
  requisição — como label, explode a cardinalidade. Ele vive em log e trace, e essa fronteira precisa
  estar escrita, porque a tentação de "correlacionar métrica com trace" é justamente colocá-lo lá.
- **O SDK do OTel passou a ficar ligado em todos os ambientes**, com exportador `none` nos testes
  (regra do documento reescrita no ticket 26). Isso significa que a instrumentação de métrica também
  está ativa em teste — vale confirmar que ela não vira dependência de Collector no CI.
- **Vocabulários separados entre batch e API** (risco aceito no ticket 26): se houver métrica de erro
  dos dois lados, ela carrega valores de `codigo` de dois catálogos distintos. Ou são duas métricas,
  ou o label precisa deixar claro qual lado gerou.

## Notas do ticket 27 (retenção × histórico)

- **Downloads de item expirado deixaram de ser um contador simples.** Como a exportação tenta buscar
  mesmo depois da data prevista (ticket 27), há dois desfechos distintos e ambos interessam: pedido
  após a data que **funcionou** (o scanner ainda não recolheu) e pedido que devolveu `410`. A razão
  entre os dois é a única medida observável da latência do scanner do MinIO, que a documentação não
  define.
- **Ocupação do bucket** vale como métrica de capacidade: com retenção global de 7 dias e volume
  diário estável, o total deveria estabilizar. Não estabilizar significa que a regra de lifecycle não
  está alcançando alguma coisa — objeto órfão, regra mal aplicada no bootstrap — e não há outro sinal
  disso.
- **`download` e `auditoria_admin` crescem para sempre** (decisão do ticket 27). Contagem de linhas
  por tabela é métrica de capacidade barata, e é o que avisa se a estimativa de volume estava errada
  por uma ordem de grandeza.

## Notas do ticket 28 (readiness e liveness)

- **O health group de dependências existe para ser consumido daqui**, não pelo Traefik. É onde
  PostgreSQL e MinIO ficam observáveis sem virar decisão de balanceamento — e é o único lugar em que a
  indisponibilidade do MinIO aparece antes de alguém tentar exportar.
- **Transições de `readiness` merecem métrica.** Com o PostgreSQL no grupo (risco aceito no ticket 28)
  e amortecimento de N falhas, a contagem de transições é o que revela vaivém: se ela sobe sem que
  haja incidente de banco, o amortecimento está curto demais.
- **Cuidado com o dobro de contagem**: a mesma indisponibilidade do banco aparece no health group, na
  métrica de erro da API e possivelmente no alerta do Grafana. Vale decidir qual delas dispara aviso,
  para o incidente não gerar três notificações da mesma coisa.

## Answer

### A regra de label

> **Um label só é permitido se seu conjunto de valores for limitado por cadastro, nunca por uso.**

| | |
|---|---|
| Permitidos | `produto`, `codigo_relatorio`, `status`, `formato`, `tipo`, `codigo` (catálogo fechado), `origem_encerramento`, `motivo`, `desfecho`, `tabela` |
| Proibidos | `data_referencia`, `usuario`, `correlation_id`, `dag_run_id`, chave do Artefato |

A conta desarma o medo que a análise comportamental levantou: 10 Códigos × 5 status ≈ **50 séries**
por métrica da Coleta, alguns milhares no total do sistema. O Prometheus lida com milhões. **Cruzar
Código com formato e status não é o problema** — o problema é label cujo conjunto cresce com o uso:
Data de Referência acrescenta 365 valores por ano, usuário é ilimitado, Correlation ID é único por
requisição.

Sobre a redundância que o documento pede (label de produto **e** de código): ela **não multiplica
séries**, porque `produto` é funcionalmente determinado por `codigo_relatorio` (`SIGLA-NNNN`,
ticket 01). Custa alguns bytes por série e poupa `label_replace` em toda consulta agregada.

### Catálogo

**Coleta**

| Métrica | Tipo | Labels |
|---|---|---|
| `coleta_duracao_segundos` | histograma | produto, codigo_relatorio |
| `coleta_partida_segundos` | histograma | produto |
| `coleta_execucoes_total` | contador | produto, codigo_relatorio, status, origem_encerramento |
| `coleta_tentativas_total` | contador | produto, codigo_relatorio |
| `coleta_linhas_processadas` | histograma | produto, codigo_relatorio |
| `artefato_tamanho_bytes` | histograma | produto, codigo_relatorio, tipo |
| `execucao_encerramento_perdido_total` | contador | produto, codigo_relatorio |

`coleta_duracao_segundos` mede **`fim − inicio_processamento`** — a mesma janela do limiar de
`ALERTA` (ticket 24). Medir por `inicio` faria painel e status discordarem.
`coleta_partida_segundos` mede **`inicio_processamento − inicio`**: é o número que justifica os 120 s
de folga do `execution_timeout` e o único jeito de perceber pull de imagem degradando.

`origem_encerramento` distingue container, callback e varredura — toda linha fechada por varredura é
infraestrutura que falhou sem avisar.

**API**

| Métrica | Tipo | Labels |
|---|---|---|
| `http_server_requests` | padrão Micrometer | uri, method, status |
| `exportacao_duracao_segundos` | histograma | produto, codigo_relatorio, formato |
| `exportacao_semaforo_ocupacao` | gauge | — |
| `exportacao_semaforo_espera_segundos` | histograma | — |
| `exportacao_recusas_total` | contador | motivo |
| `download_total` | contador | produto, codigo_relatorio, formato, via_bypass |
| `download_apos_expurgo_total` | contador | desfecho (`entregue` \| `expirado`) |
| `erro_total` | contador | codigo |

A duração de exportação **não é simétrica**: PDF, XLSX e DOCX desserializam; o CSV não (ticket 23).
Medi-los juntos esconde exatamente a diferença que importa para dimensionar heap.

`download_apos_expurgo_total` com os dois desfechos é a **única medida observável** da latência do
scanner do MinIO, que a documentação não define (ticket 27).

**Capacidade**

| Métrica | Tipo | Labels |
|---|---|---|
| `bucket_objetos_total`, `bucket_bytes_total` | gauge | — |
| `tabela_linhas` | gauge | tabela |
| `readiness_transicoes_total` | contador | — |
| `series_total` | gauge | — |

Com retenção global de 7 dias e volume diário estável, a ocupação do bucket deveria **estabilizar**.
Não estabilizar significa que a regra de lifecycle não está alcançando alguma coisa, e não há outro
sinal disso.

**Erro de batch é métrica separada** da de API, porque o ticket 26 aceitou vocabulários distintos —
juntá-las faria o mesmo label `codigo` carregar valores de dois catálogos.

### Risco aceito 1: a guarda é documental

Argumentei por verificação executável — um teste que percorre o `MeterRegistry` e falha no build se
aparecer label fora da lista. Cardinalidade é o tipo de erro que **não dá sintoma** até o Prometheus
adoecer, e revisão de código não pega label acrescentado meses depois por quem nunca leu esta decisão;
o diagnóstico chega semanas atrasado e longe da causa.

Decisão: regra documentada, valendo como critério de revisão.

### Risco aceito 2: alertas sem notificação

Argumentei por contato SMTP no Grafana — que **não** contraria o ticket 16, onde o que se recusou foi
dar remetente próprio à **aplicação**; o Grafana é ferramenta operacional, não código de aplicação.

Decisão: as regras existem e pintam o painel; ninguém é notificado.

**O efeito é composto e maior que o próprio risco.** Três riscos aceitos em outros tickets são
contidos por "alerta no Grafana":

| Ticket | Risco aceito lá | Contenção que enfraquece aqui |
|---|---|---|
| 02 — Ciclo de vida | `LIMITE_ORFA` global | `execucao_encerramento_perdido` |
| 24 — Tolerância do tempo estimado | `ALERTA` não notifica pela aplicação | alerta por padrão, não por ocorrência |
| 25 — Geração sob demanda | teto de tamanho só na exportação | `tamanho_artefato_bytes` acima do teto |

As três passam a depender de alguém abrir o Grafana. Um risco contido por observação que ninguém faz
é um risco não contido — e isso está registrado aqui, num lugar só, em vez de espalhado.

### A contenção: o painel-resumo

Deixa de ser organização visual e vira o mecanismo que sustenta as três contenções acima.

Uma tela que responde **"algo precisa de atenção agora?"** em dez segundos, como **destino padrão** de
quem abre o Grafana:

```
encerramento perdido           0
ALERTA recorrente              POUPANCA-0001 (4 dias)
artefato acima do teto         nenhum
Execuções fechadas pela varredura   0 hoje
Coletas do dia                 9 ok / 1 erro
séries no Prometheus           3.812
```

A última linha entra pela composição dos dois riscos desta sessão: como a guarda de cardinalidade é
**documental**, o painel é o único lugar onde um label indevido apareceria antes de o Prometheus
degradar.

Abaixo dele, os painéis por tema — Coleta, Exportação, Capacidade — com a profundidade de cada área.

## Notas do ticket 36 (varredura de órfãs)

- **Métrica nova: `varredura_idade_segundos`** — segundos desde a última execução bem-sucedida da
  varredura. Sem labels. Ela é o "quem vigia o vigia": rodando a cada 15 min, qualquer valor muito
  acima disso é anomalia óbvia.
- **Ela ganha linha própria no painel-resumo**, ao lado das outras. É o quarto sinal que a tela
  carrega, e o padrão se mantém: um lugar só responde "algo precisa de atenção agora?".
- **A alternativa era o `DeadlineAlert` do Airflow**, recusada porque o aviso moraria na UI do
  orquestrador — uma segunda tela a consultar, o que fragmenta justamente a contenção que o
  painel-resumo é.

## Notas do ticket 37 (versionamento do JRXML)

- **Métrica nova: `inventario_divergente`**, com label `codigo_relatorio` — limitado por cadastro,
  então cabe na regra deste ticket. Incrementa quando o hash calculado pelo container difere do
  gravado em `jrxml_publicado`, ou seja, quando alguém subiu imagem sem rerodar
  `--publicar-inventario`.
- **Ela não vai ao painel-resumo.** É problema de higiene de deploy, não de "algo precisa de atenção
  agora?" — e o painel-resumo já carrega quatro sinais por não haver canal de notificação. Enfileirar
  um quinto que não exige ação imediata é o começo da diluição.
