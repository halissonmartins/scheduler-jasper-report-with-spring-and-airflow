# Especificação — Scheduler Jasper Report

Especificação técnica pronta para implementar. Consolida as 49 decisões do
[mapa](mapa/map.md) e os três ADRs, e substitui a `descricao-inicial.md` como fonte normativa
onde os dois divergirem — as divergências estão listadas em [Notas adicionais](#notas-adicionais).

A linguagem ubíqua está em [`CONTEXT.md`](../CONTEXT.md) e é usada aqui sem redefinição:
**Produto**, **Sigla**, **Relatório**, **Código de Relatório**, **Coleta**, **Execução**,
**Data de Referência**, **Artefato**, **Exportação**, **Download**, **Perfil**,
**Role de Relatório**, **Grupo**, **Pendente de Vínculo**.

---

## Problema

Uma instituição financeira tem cinco domínios de negócio com bases transacionais próprias —
Poupança, Cliente, Conta Corrente, Consórcio e Empréstimo. As pessoas que precisam dos relatórios
desses domínios não têm como obtê-los: consultar a base transacional diretamente é caro para o
banco no horário de trabalho, exige acesso que essas pessoas não deveriam ter, e produz um número
diferente a cada vez que alguém roda a consulta.

Do ponto de vista de quem usa:

- **O relator** precisa do relatório de ontem em PDF para levar a uma reunião, e da mesma
  informação em planilha para conferir uma conta. Hoje ele pede a alguém, espera, e recebe um
  arquivo que não sabe de que momento é. Quando pede de novo na semana seguinte, os números
  mudaram, e ele não consegue dizer se mudaram porque o dado mudou ou porque a consulta mudou.
- **O gerente** precisa controlar quem enxerga o quê. Um relatório de Empréstimo não deve estar
  ao alcance de quem cuida de Poupança. Hoje esse controle não existe em lugar nenhum que ele possa
  administrar — e quando alguém novo entra, não há sequer uma fila mostrando que essa pessoa está
  esperando acesso.
- **O administrador** precisa saber se a rotina da madrugada funcionou. Hoje a única forma de
  descobrir que um relatório não foi gerado é o relator reclamar, no meio da manhã, de que a tela
  está vazia. E quando algo demora mais do que o normal, nada avisa — a degradação só vira visível
  quando vira falha.
- **Quem opera** precisa investigar. Um erro na tela hoje é uma mensagem genérica sem nada que
  ligue o que o usuário viu ao que o servidor registrou.

A restrição que atravessa tudo: **a base transacional de cada Produto só pode ser lida uma vez por
dia, por um processo controlado**. Qualquer desenho em que a geração do relatório vá à base
transacional no momento do pedido está fora.

---

## Solução

Duas metades que se encontram num repositório de objetos compatível com S3.

**A Coleta** roda agendada, uma vez por dia por Produto. O Airflow abre a Execução no schema de
controle e sobe um container Spring Batch; esse container lê o schema transacional do seu Produto
— a **única** fronteira de leitura dessas bases —, preenche o relatório e grava dois Artefatos: o
`.jrprint` (o relatório preenchido, do qual saem PDF, XLSX e DOCX) e o `.csv.gz` (o dataset bruto
da consulta principal). Ao terminar, registra os metadados da Execução.

**A Exportação** acontece sob demanda, na API REST. O relator vê a lista do que está disponível
para ele, escolhe uma Execução e um formato, e recebe os bytes na mesma requisição. A API busca o
Artefato, confere o SHA-256, desserializa e exporta — nunca toca numa base transacional.

O que isso entrega a cada um:

- O relator abre uma tela, filtra por data, Produto ou Código, e baixa. O que ele vê é o que ele
  pode baixar — listagem e geração saem da mesma fonte de autorização, então não discordam.
- O gerente cria Roles de Relatório, vincula-as a Grupos, e põe pessoas nos Grupos. Vê a fila de
  quem se cadastrou e está esperando. Nunca recebe credencial do Keycloak: tudo passa pela
  mediação da API, e cada ação — inclusive as recusadas — vira linha de auditoria.
- O administrador cadastra Produtos e Relatórios, define o tempo estimado de cada um, e enxerga o
  histórico de Execuções com dois verbos de reação: `refazer` o que não deu certo e `reprocessar`
  o que deu certo mas precisa ser refeito. Um painel-resumo responde em dez segundos se algo
  precisa de atenção.
- Toda resposta de erro carrega código estável, momento e Correlation ID — que é o traceId do
  OpenTelemetry, o mesmo que busca o log no Graylog e o trace no Jaeger.

---

## Histórias de usuário

### Relator — encontrar e baixar

1. Como RELATOR, quero me cadastrar pela interface web pública, para não depender de alguém abrir
   um chamado por mim.
2. Como RELATOR recém-cadastrado, quero receber um e-mail de verificação de endereço, para provar
   que o endereço é meu antes de entrar.
3. Como RELATOR ainda sem Grupo, quero entrar no sistema e ver uma página dedicada explicando que
   aguardo configuração de permissões, para saber que meu cadastro chegou e o que falta.
4. Como RELATOR, quero ver numa única lista todas as Execuções disponíveis para mim, para não ter
   de adivinhar em que data ou Produto está o que procuro.
5. Como RELATOR, quero filtrar essa lista por Data de Referência, por Produto e por Código de
   Relatório, para chegar rápido ao que quero num acervo de vários dias.
6. Como RELATOR, quero que a lista mostre apenas os Relatórios a que tenho acesso, para não
   descobrir uma recusa só depois de clicar.
7. Como RELATOR, quero distinguir na lista um item disponível de um que ficou lento, de um sem
   dados e de um expirado, para saber o que esperar antes de clicar.
8. Como RELATOR, quero que um item que só demorou (`ALERTA`) não pareça um problema, porque ele é
   perfeitamente baixável.
9. Como RELATOR, quero baixar em PDF, para levar o relatório formatado a uma reunião.
10. Como RELATOR, quero baixar em XLSX, para trabalhar sobre a mesma visão formatada numa planilha.
11. Como RELATOR, quero baixar em DOCX, para colar trechos num documento.
12. Como RELATOR, quero baixar em CSV, para analisar o dataset bruto da consulta principal em outra
    ferramenta.
13. Como RELATOR, quero que o CSV abra corretamente no Excel em português — acentos, colunas
    separadas e números somáveis — sem eu configurar nada.
14. Como RELATOR, quero ver um estado de espera visível enquanto a exportação acontece, para não
    confundir uma tela trabalhando com uma tela travada.
15. Como RELATOR, quero que o arquivo baixado tenha um nome que identifique Relatório, data e
    formato, para achá-lo depois na pasta de downloads.
16. Como RELATOR, quero que um item marcado como expirado ainda tente baixar, porque o expurgo é
    assíncrono e pode ser que ele ainda esteja lá.
17. Como RELATOR, quero que o selo de expirado mostre a data real do expurgo, e não uma promessa
    genérica de sete dias.
18. Como RELATOR, quero ver uma mensagem específica quando a Coleta rodou e a origem não tinha
    linhas, para distinguir isso de um relatório que nunca existiu.
19. Como RELATOR, quero saber, quando a exportação é recusada por capacidade, que vale a pena
    tentar de novo — e saber, quando ela é recusada por tamanho, que não vale.
20. Como RELATOR, quero copiar o Correlation ID da tela de erro com um clique, para passá-lo ao
    suporte.
21. Como RELATOR, quero trocar minha senha sem pedir a ninguém.
22. Como RELATOR, quero encerrar a sessão de forma que ela realmente termine no provedor de
    identidade, não só no navegador.
23. Como RELATOR, quero permanecer logado em mais de um navegador, porque uso desktop e celular.

### Gerente — conceder e revogar acesso

24. Como GERENTE, quero ver, ao entrar, quantos cadastros aguardam vínculo, para saber que há
    trabalho me esperando.
25. Como GERENTE, quero listar quem está Pendente de Vínculo com há quanto tempo espera, ordenado
    pelos mais antigos, para não deixar ninguém esquecido.
26. Como GERENTE, quero que essa lista mostre apenas cadastros com e-mail verificado, para não
    trabalhar sobre endereços que ninguém confirmou.
27. Como GERENTE, quero criar Roles de Relatório sob um padrão de nome que carregue a Sigla do
    Produto, para saber a que Produto cada uma pertence só de ler o nome.
28. Como GERENTE, quero ser recusado ao tentar criar uma Role fora desse padrão, para não abrir
    caminho de escape do domínio de relatórios.
29. Como GERENTE, quero vincular Relatórios a uma Role de Relatório, para definir o que aquela
    chave abre.
30. Como GERENTE, quero ser recusado ao tentar montar uma Role que misture Relatórios de Produtos
    diferentes, porque o nome dela passaria a mentir.
31. Como GERENTE, quero criar e remover Grupos, para organizar as pessoas por equipe.
32. Como GERENTE, quero vincular Roles de Relatório a Grupos, para conceder acesso a um conjunto de
    pessoas de uma vez.
33. Como GERENTE, quero incluir um RELATOR num Grupo e que ele saia da fila de pendentes na mesma
    operação, para o contador não continuar contando quem já foi atendido.
34. Como GERENTE, quero ser recusado ao vincular alguém a um Grupo que não tem Role alguma, porque
    isso apagaria o sinal de que a pessoa esperava e entregaria zero relatórios.
35. Como GERENTE, quero saber quando a vinculação falhou pela metade, em vez de receber um sucesso
    silencioso.
36. Como GERENTE, quero remover um RELATOR de um Grupo, para revogar acesso quando alguém muda de
    função.
37. Como GERENTE, quero excluir um RELATOR, para desfazer um cadastro indevido.
38. Como GERENTE, quero ver os usuários da minha alçada consultando o estado real do provedor de
    identidade, e não uma cópia que pode estar velha.
39. Como GERENTE, quero ser impedido de criar outro GERENTE ou de alcançar um ADMINISTRADOR, para
    que um erro meu não vire escalonamento de privilégio.
40. Como GERENTE, quero ser impedido de apagar o grupo que recebe os cadastros novos, porque isso
    desligaria o onboarding inteiro em silêncio.

### Administrador — cadastrar e operar

41. Como ADMINISTRADOR, quero cadastrar um Produto com Sigla própria e imutável, para que renomear
    o Produto depois seja seguro.
42. Como ADMINISTRADOR, quero definir o horário da Coleta de cada Produto por expressão cron, para
    alinhá-la ao momento em que a base de origem fica pronta.
43. Como ADMINISTRADOR, quero ser recusado ao informar um cron de granularidade absurda, para não
    subir container a cada minuto.
44. Como ADMINISTRADOR, quero cadastrar um Relatório apenas com um Código que exista no inventário
    publicado, para que Relatório fantasma seja impossível.
45. Como ADMINISTRADOR, quero que a tela de cadastro me ofereça o tempo estimado sugerido pelo
    módulo, para eu ter um ponto de partida num Relatório sem histórico.
46. Como ADMINISTRADOR, quero ser recusado ao cadastrar um tempo estimado que a varredura de órfãs
    não comporta, para que ela não feche uma Coleta viva.
47. Como ADMINISTRADOR, quero ver o inventário publicado com os dois descompassos — publicado e não
    cadastrado, cadastrado e não publicado — para diagnosticar por que um Relatório não roda.
48. Como ADMINISTRADOR, quero ver o histórico de Execuções com status, início, fim e linhas
    processadas, para saber o que aconteceu na madrugada.
49. Como ADMINISTRADOR, quero `refazer` uma Coleta cuja última tentativa falhou ou não achou dados,
    sem precisar justificar, porque não há nada a destruir.
50. Como ADMINISTRADOR, quero `reprocessar` uma Coleta bem-sucedida informando o motivo, porque
    isso apaga a Execução anterior e sobrescreve os Artefatos.
51. Como ADMINISTRADOR, quero que o sistema decida qual dos dois verbos é válido, para eu nunca
    destruir algo achando que estou só refazendo.
52. Como ADMINISTRADOR, quero alcançar todos os Relatórios sem depender de Role de Relatório, para
    conferir um Relatório recém-cadastrado sem pedir permissão a quem está abaixo de mim.
53. Como ADMINISTRADOR, quero que meus downloads fiquem marcados como acesso por Perfil, para que a
    auditoria distinga isso de acesso concedido por Role.
54. Como ADMINISTRADOR, quero consultar o histórico de Downloads e que ele continue legível mesmo
    depois de o Relatório, o usuário ou o Artefato deixarem de existir.
55. Como ADMINISTRADOR, quero consultar a auditoria administrativa, incluindo as tentativas
    recusadas, porque num modelo de gerente global é a única evidência de alguém tateando a
    fronteira.
56. Como ADMINISTRADOR, quero cadastrar e remover usuários GERENTE e ADMINISTRADOR.
57. Como ADMINISTRADOR, quero remover Produtos e Relatórios.

### Operação e observabilidade

58. Como operador, quero um painel-resumo que responda em dez segundos se algo precisa de atenção,
    porque não há canal de notificação e todo incidente começa por alguém olhando uma tela.
59. Como operador, quero ver quantas Execuções foram fechadas pela varredura hoje, porque cada uma
    é infraestrutura que falhou sem avisar.
60. Como operador, quero um sinal de que a própria varredura parou de rodar, para o vigia não ficar
    sem vigia.
61. Como operador, quero ver `ALERTA` recorrente por Código de Relatório, para distinguir
    degradação gradual de variação de carga.
62. Como operador, quero ver o tamanho dos Artefatos por Código, para descobrir um Relatório que
    ficou grande demais antes de o relator descobrir no clique.
63. Como operador, quero ver a ocupação do repositório de objetos, porque com retenção fixa ela
    deveria estabilizar — e não estabilizar é o único sinal de lifecycle não alcançando algo.
64. Como operador, quero medir separadamente o tempo de partida do container e o tempo de trabalho
    da Coleta, para saber se o problema é pull de imagem ou consulta.
65. Como operador, quero que a duração medida na métrica seja exatamente a que decide o `ALERTA`,
    para painel e tabela não discordarem.
66. Como operador, quero saber quando uma imagem subiu sem republicar o inventário, para rerodar o
    passo de bootstrap.
67. Como operador, quero que logs, traces e métricas cheguem ao Collector com traceId e spanId, para
    correlacionar log e trace pelo mesmo identificador que o usuário me passou.
68. Como operador, quero que a API responda `UP` em liveness e readiness na porta 8080, e que só
    esses dois caminhos estejam publicados.
69. Como operador, quero que o liveness nunca dependa de recurso externo, para o container não
    entrar em laço de reinício durante uma indisponibilidade do banco.
70. Como operador, quero que o readiness só caia após falhas consecutivas do banco e volte na
    primeira que passar, para uma instabilidade de dois segundos não tirar instâncias de rotação.
71. Como operador, quero que a API continue listando quando o repositório de objetos estiver fora,
    falhando apenas na exportação, com código e Correlation ID.
72. Como operador, quero um deploy por script idempotente que exija o SHA como parâmetro, para o
    que roda em produção ser sempre o que passou nos testes.
73. Como operador, quero que o deploy confira o que ele não automatiza — chave de licença, árvore de
    Grupos, Mailpit, allowlist — e falhe alto em vez de seguir em silêncio.
74. Como operador, quero voltar de uma versão redeployando o SHA anterior sem tocar no banco, o que
    exige que toda migração seja aditiva e compatível com a imagem anterior.
75. Como operador, quero um runbook organizado pelos sinais do painel-resumo, e não por componente,
    porque é dali que todo incidente começa.

### Desenvolvimento e extensão

76. Como desenvolvedor, quero acrescentar um Relatório declarando um bean, para que declarar e
    poder executar sejam a mesma coisa.
77. Como desenvolvedor, quero que o Starter cuide de leitura, CSV, virtualizer, telemetria,
    timeout, hash e escrita dos metadados, para o módulo do Produto conter apenas consulta,
    mapeamento, rótulos e JRXML.
78. Como desenvolvedor, quero que o Starter imponha o step single-thread, para eu não corromper
    metadados adicionando paralelismo sem saber.
79. Como desenvolvedor, quero acrescentar um Produto novo sem editar o Airflow, porque as DAGs são
    geradas a partir de um snapshot que a API materializa.
80. Como desenvolvedor, quero que o CSV e o `.jrprint` venham da mesma passada de leitura, para que
    divergência de linhas entre eles seja impossível por construção.
81. Como desenvolvedor, quero que cada Execução registre a versão do JasperReports, o hash da
    definição e a imagem de origem, para que divergência silenciosa vire fato gravado.
82. Como desenvolvedor, quero que a comparação de hash aponte para o commit, para o `git diff`
    responder *o quê* mudou onde o hash só sabe dizer *se* mudou.
83. Como desenvolvedor, quero que o job saia com código diferente de zero quando falha, para o
    Airflow não marcar sucesso num job falho.
84. Como desenvolvedor, quero que a leitura da base transacional seja realmente transmitida, e não
    bufferizada em silêncio pelo driver.
85. Como desenvolvedor, quero que a credencial do meu módulo não consiga ler o schema de outro
    Produto, para o banco impor a fronteira em vez de eu confiar em disciplina.
86. Como desenvolvedor, quero um catálogo de erros fechado e estável, para o front mapear
    comportamento sem manter um segundo catálogo de textos.
87. Como revisor, quero que cada cenário obrigatório da especificação seja um teste marcado que o CI
    exige ter **rodado e passado**, e não apenas existir.

---

## Decisões de implementação

### 1. Módulos e linguagem

`groupId` `br.com.relatorios`. Domínio em português, andaime técnico em inglês.

| Módulo | Papel |
|---|---|
| `relatorios-comum` | biblioteca compartilhada: conversor de authorities, migrações do schema de controle, contrato de erro |
| `relatorios-processador-starter` | o Starter da Coleta com Spring Batch |
| `relatorios-api` | API REST — listagem, exportação, cadastro, mediação do Keycloak |
| `relatorios-processador-{poupanca,cliente,contacorrente,consorcio,emprestimo}` | um por Produto |
| `relatorios-web` | frontend Angular |

Sigla do Produto é dado próprio, único e **imutável** ([ADR 0001](adr/0001-sigla-do-produto-imutavel.md)).
Nome do Produto é rótulo apresentacional e livremente alterável. A sequência de quatro dígitos do
Código de Relatório é única **por Produto** (teto de 9.999 por Produto).

### 2. Stack e versões

Java 25 (Temurin), Spring Boot 4.1.x, **Spring Batch 6**, JasperReports **7.0.7 como piso de
segurança** (CVE-2026-6009 — RCE de desserialização até a 7.0.6), Maven 3.9.16 com `${revision}` e
`flatten-maven-plugin`, JaCoCo 0.8.15 agregado num módulo dedicado. PostgreSQL 18 com minor fixa.
Flyway na versão do BOM. Keycloak 26.7.0 com tag fixada — a comunidade não tem LTS. Airflow 3.3.x.
Traefik v3.7. Angular 22.1 zoneless com TypeScript `~6.0.0`, Node 24, Angular Material,
`angular-auth-oidc-client`. Logback, **não** Log4j2.

`JRConstants.SERIAL_VERSION_UID` é a constante fixa `10200` em todas as versões do Jasper: leitura
cruzada entre versões **falha em silêncio**, não com `InvalidClassException`. Daí a versão única
imposta por enforcer no POM raiz e gravada em cada Execução.

**Repositório de objetos**: "MinIO" é implementação, nunca contrato — o código fala S3 puro atrás de
uma porta, com AWS SDK v2, path-style e checksum explícito. O repositório `minio/minio` foi
arquivado em 25/04/2026; dev e CI rodam o último binário AGPL congelado, produção roda **AIStor
Free** ([ADR 0003](adr/0003-repositorio-s3-aistor-free-em-producao.md)).

### 3. Naturezas de schema e ownership

```
transacional_<sigla>   um por Produto — lido exclusivamente pela sua própria Coleta
controle               metadados, artefatos, inventário, downloads, auditoria
```

Não existe schema do JobRepository: o Spring Batch 6 traz `ResourcelessJobRepository` como default e
o projeto o adota. Isso elimina uma natureza de schema, uma instância Flyway e um segundo registro
do que rodou — ao custo de **steps obrigatoriamente single-thread**, sem particionamento e sem
restart de meio de job (o retry é do Airflow).

Uma instância Flyway por natureza, `baselineOnMigrate=false`. As migrações do `controle` rodam como
passo de bootstrap, nunca no arranque de um container de aplicação.

**Sete usuários de banco**, com o `GRANT` impondo a fronteira arquitetural:

```
app_proc_<sigla>   SELECT em transacional_<sigla>            (5 usuários)
                   INSERT/UPDATE em controle.execucao, controle.artefato
app_airflow        INSERT/UPDATE em controle.execucao        (T1, T6, T7)
app_api            SELECT em controle.*  +  INSERT em controle.download
```

A regra original *"escrita pelos processadores, leitura pela API"* está **reescrita**: há três
escritores — processadores, Airflow e API (só `download`) — e um leitor amplo, a API.

**`agencia` existe duplicada** entre `transacional_poupanca` e `transacional_contacorrente`. É
consequência direta do isolamento, não erro de modelagem: "consertar" com schema compartilhado
derrubaria o `GRANT` que sustenta a segregação.

### 4. Modelo do schema de controle

- **`produto`** — `sigla` (PK, imutável), `nome` (mutável), `cron`.
- **`relatorio`** — `codigo` (PK, `SIGLA-NNNN`), FK para `produto`, `nome`, `descricao`,
  `tempo_estimado_segundos` (NOT NULL, > 0).
- **`jrxml_publicado`** — o inventário: `codigo_relatorio`, imagem de origem, caminho do JRXML,
  `hash_definicao`, `publicado_em`.
- **`execucao`** — `codigo_relatorio`, `data_referencia` (`DATE`, semântica `America/Sao_Paulo`),
  `status`, `inicio` / `inicio_processamento` / `fim` (`timestamptz` UTC), `linhas_processadas`,
  `correlation_id`, `dag_run_id`, `versao_jasperreports`, `hash_definicao`, `imagem_origem`,
  `parametros_entrada` (`jsonb`), `detalhe_erro` (`jsonb`, com a **origem** do encerramento),
  `solicitante` e `motivo` do reprocessamento.
- **`artefato`** — 1:N com `execucao`: `tipo` (`JRPRINT`, `CSV_GZ`), `chave` completa, `sha256`,
  `tamanho_bytes`, `data_expurgo_prevista`. `UNIQUE (execucao_id, tipo)`.
- **`relatorio_role_relatorio`** — N:N entre Código de Relatório e nome da role `REL_*`, com
  constraint de que todos os Relatórios de uma mesma Role pertençam ao **mesmo Produto**. Índice por
  `nome_role` é requisito, não otimização: é a consulta mais frequente do schema.
- **`download`** — fotografia denormalizada, com `execucao_id` `ON DELETE SET NULL` e marcação de
  bypass por Perfil.
- **`auditoria_admin`** — trilha das ações de mediação, denormalizada, gravando também as
  **recusas**.

`jsonb` fica restrito a `parametros_entrada` e `detalhe_erro`. Valor que se compara entre linhas é
coluna. Não existem colunas de "expirado" nem de "atrasada" — os dois são derivados na leitura.

**Nenhum espelho do Keycloak.** Usuário, Grupo e Role de Relatório vivem só lá; o schema de controle
guarda apenas `relatorio_role_relatorio`, o único elo da cadeia que o Keycloak não sabe representar.

**O inventário manda sobre o que pode ser cadastrado.** O ADMINISTRADOR só cadastra Código presente
em `jrxml_publicado`, publicado por um modo `--publicar-inventario` da própria imagem do processador
num passo idempotente de bootstrap. A publicação é **declarativa**: um Relatório cujo bean saiu da
imagem sai do inventário, o cadastro permanece sinalizado como "cadastrado, não publicado", e a
fábrica de DAGs para de gerar DAG para ele.

`download` e `auditoria_admin` **crescem indefinidamente** — o histórico sobrevive ao expurgo dos
Artefatos por exigência do produto. O acúmulo de dado pessoal está registrado como escolha
consciente, coerente com classificação e mascaramento estarem fora de escopo.

### 5. Ciclo de vida da Execução

Cinco valores num campo único. `EM_PROCESSAMENTO` é o inicial e o único não-terminal; os demais são
terminais e **imutáveis**.

Precedência no encerramento, da maior para a menor:

```
1. ERRO       timeout duro no dobro do estimado, ou falha fatal
2. SEM_DADOS  completou, zero linhas na origem
3. ALERTA     completou com dados, passou do tempo estimado
4. SUCESSO    completou com dados, dentro do tempo estimado
```

A fronteira entre `ALERTA` e `ERRO` é **ter completado**, não a duração. A regra original ("o alerta
prevalece sobre o erro") passa a se ler como falhas **de item** numa Execução que terminou; falha de
job é `ERRO` em qualquer duração.

Invariantes que sustentam a listagem:

```
SUCESSO   => Artefato existe, com conteúdo
ALERTA    => Artefato existe, com conteúdo
SEM_DADOS => nenhum Artefato gravado
ERRO      => nenhum Artefato íntegro
```

`SEM_DADOS` encerra **antes** do fill, sem gravar nada — o que evita de saída o `.jrprint` de zero
páginas. Aparece na listagem, marcada, sem download.

| # | De | Para | Quem |
|---|---|---|---|
| T1 | — | `EM_PROCESSAMENTO` | Airflow, task `abrir_execucao`, antes de subir o container |
| T2 | `EM_PROCESSAMENTO` | `SUCESSO` | container |
| T3 | `EM_PROCESSAMENTO` | `ALERTA` | container |
| T4 | `EM_PROCESSAMENTO` | `SEM_DADOS` | container |
| T6 | `EM_PROCESSAMENTO` | `ERRO` | Airflow, `on_failure_callback`, ao esgotarem os retries |
| T7 | `EM_PROCESSAMENTO` | `ERRO` | Airflow, DAG de varredura |

**O container nunca grava `ERRO`** — ele sai com código diferente de zero e deixa a linha aberta.
**A API REST não dispara transição alguma.** Toda escrita terminal leva `AND status =
'EM_PROCESSAMENTO'`: primeiro escritor vence; casar zero linhas incrementa
`execucao_encerramento_perdido` e não sobrescreve.

Materializa-se o que é conhecido no encerramento; deriva-se o que depende do relógio (`atrasada`,
`expirado`). Por isso `ALERTA` só é avaliado no encerramento, e "expirado" não é status.

**Não existe `CANCELADO`** — nenhuma tela, endpoint ou Perfil tem essa capacidade, e interrupção
manual é indistinguível de queda de VM: cai como `ERRO` pela varredura.

### 6. Unicidade, retry e reprocessamento

```sql
CREATE UNIQUE INDEX ON execucao (codigo_relatorio, data_referencia)
  WHERE status NOT IN ('ERRO', 'SEM_DADOS');
```

**Este índice é a regra de unicidade inteira**, imposta pelo banco em T1, antes de gastar container.
Não há checagem equivalente na aplicação. `SEM_DADOS` está fora porque uma Execução sem Artefato não
tem o que proteger — o que resolve o caso comum de origem atrasada sem exigir justificativa formal.

Dois verbos de disparo manual, ambos restritos a ADMINISTRADOR e ambos auditados:

| Verbo | Quando é válido | Destrói | Exige motivo |
|---|---|---|---|
| `refazer` | o par está livre no índice | não | não |
| `reprocessar` | há `SUCESSO` ou `ALERTA` ocupando o par | sim | sim |

**A API decide qual é válido consultando o índice** — o usuário não adivinha, e não existe caminho
em que ele destrua algo achando que só refaz. A autorização fica na API, nunca nas permissões do
Airflow.

`reprocessar` **apaga** a Execução anterior e suas linhas de `artefato`, e herda a Data de Referência
da original. Sem essa herança, reprocessar dias depois geraria chave nova e a unicidade nunca
dispararia.

**Retry não é reprocessamento.** `abrir_execucao` e o `DockerOperator` são tasks separadas: o Airflow
retenta só a segunda, **a linha é reusada**, e o `on_failure_callback` a fecha como `ERRO` uma única
vez ao esgotarem as tentativas.

*Risco aceito, composto:* depois de um reprocessamento não sobra forma de verificar o que foi
substituído — a Execução antiga não existe, o `sha256` foi junto, o `execucao_id` do Download virou
nulo, e o Download não guarda o hash do que entregou. A auditoria responde quem e por quê, nunca
o quê.

### 7. Chave de armazenamento, fuso e retenção

Data de Referência é o dia em que a Coleta rodou, calculada em **`America/Sao_Paulo`**; instantes
são `timestamptz` em UTC. Regra: **data de calendário é do negócio, instante é UTC**.

```
{yyyy-MM-dd}/{SIGLA}/{CODIGO}/{CODIGO}.jrprint
{yyyy-MM-dd}/{SIGLA}/{CODIGO}/{CODIGO}.csv.gz
```

Sem discriminador de execução: reprocessar sobrescreve. O caminho é determinístico, mas o schema de
controle **grava a chave completa** para sobreviver a uma mudança de layout sem reescrever histórico.
O SHA-256 não vira arquivo no bucket — ele vive no schema de controle. Competência não é modelada; se
um dia entrar, entra como coluna, nunca como componente do caminho.

**Retenção global**, variável de ambiente com padrão 7 dias, **uma** regra de lifecycle nativo com
**filtro vazio** sobre o bucket inteiro. O filtro vazio recolhe também objetos órfãos de upload
interrompido — a única limpeza que existe, já que **nenhuma credencial tem `s3:DeleteObject`**. A
credencial da API também não tem `s3:ListBucket`: ela busca por chave conhecida.

`data_expurgo_prevista` vem do header `x-amz-expiration` do `PutObject` quando o servidor o emite,
com fallback para o cálculo local. "Sete dias" é aproximado em relação à data de negócio, porque a
expiração arredonda para a meia-noite UTC — a mensagem informa a **data real**.

**A listagem avisa, a exportação verifica.** A marcação de expirado é derivada da data e é
conservadora, porque o expurgo depende de um scanner de baixa prioridade. A exportação **tenta
buscar assim mesmo** e só devolve `410` se o objeto não estiver lá. Isso dissolve a não-atomicidade
entre os dois Artefatos: cada formato responde pelo que existe naquele instante.

### 8. Contrato entre o Airflow e o container

**Uma DAG por Relatório** (`coleta_<CODIGO>`, com tag do Produto), com **uma task por Relatório** —
a mesma unidade da Execução, da constraint e do tempo estimado. A DAG tem duas tasks:
`abrir_execucao` (sem retry) e o `DockerOperator` (`retries = 2`), com `on_failure_callback`
**obrigatório** — sem ele a Execução fica aberta até a varredura.

**Uma imagem por módulo processador.** *Risco aceito*: divergência de versão do Jasper entre imagens
é possível em deploy e falha em silêncio. **Contenção obrigatória**: antes de desserializar, a API
compara `versao_jasperreports` da Execução com a sua; divergindo, **exporta assim mesmo** e alerta.
Recusar quebraria os sete dias seguintes a todo upgrade legítimo.

Entrada por variáveis de ambiente (`environment` templated do `DockerOperator`, credenciais em
`private_environment`): identificador da **Execução já aberta**, Código de Relatório, Data de
Referência, `traceparent`, credenciais do Produto e do repositório.

Exit codes:

```
SUCESSO | ALERTA | SEM_DADOS  -> 0
falha do job                  -> 5   (sem gravar terminal)
falha antes de registrar      -> ≠ 0
SIGKILL (OOM ou fim do grace) -> 137
```

**`main()` precisa ser `System.exit(SpringApplication.exit(ctx, ...))`.** Sem isso o
`ExitCodeGenerator` não age, um job Batch falho sai com código 0, e o Airflow marca `success`. É
requisito de contrato, entregue pelo Starter — não deixado a cada módulo.

`SEM_DADOS` **não** usa `skip_on_exit_code`: `skipped` propaga rio abaixo e o status real já está no
banco.

`data_referencia` entra por `params` tipado; o template serve só de default do caminho agendado,
**com conversão explícita de fuso** — `{{ ds }}` cru rotula errado toda Coleta agendada depois das
21h BRT.

### 9. Tempos, tolerância e timeouts

Sendo `E` o tempo estimado cadastrado, em segundos:

| | |
|---|---|
| `ALERTA` | duração de trabalho > `E × 1,20` |
| Timeout duro interno | `E × 2` — o container se mata |
| `execution_timeout` do Airflow | `E × 2 + 120 s` |
| Tentativas | 3 (`retries = 2`) |
| `LIMITE_ORFA` | 6 h, global |
| Guarda no cadastro | `3 × (2E + 120) ≤ LIMITE_ORFA` → **`E ≤ 3540 s` (~59 min)** |

**Limiar fixo, não adaptativo.** Um limiar por média móvel acompanha a degradação gradual e nunca
alerta — o sinal que existe para avisar disso seria o primeiro a sumir.

**A duração avaliada é `fim − inicio_processamento`**, não `fim − inicio`. Medir pelo `inicio`
(gravado em T1) colocaria pull de imagem e partida da JVM dentro da janela e dispararia `ALERTA` em
todo Relatório curto. A varredura de órfãs continua usando `inicio`, porque ela mede **abandono**,
não desempenho.

O teto de ~59 min é **guarda de orquestração**, não limite de tamanho de Relatório — quem limita
tamanho é o heap da exportação, e os dois números não se conversam.

*Lacuna registrada e não corrigida:* volume sazonal não é atendido por `tempo_estimado` como número
único. Nenhum dos dez Relatórios tem duração sazonal. O sintoma, quando aparecer, é `ALERTA`
recorrente em datas previsíveis; a saída a tentar primeiro é **modelagem antes de mecanismo**.

**Artefatos parciais**: os dois Artefatos são escritos em disco local durante a Coleta e subidos ao
repositório só depois do fill completo; as linhas de `artefato` e o status terminal são gravados
apenas quando os dois uploads terminam. Upload interrompido deixa objeto órfão sem metadado,
invisível ao sistema e recolhido pela retenção.

### 10. Varredura de órfãs

DAG **estática** do Airflow — não sai da fábrica, não sobe container, não consome o pool de Coletas.
Roda a cada **15 minutos**: com `LIMITE_ORFA` de 6 h a frequência é puro atraso de detecção, e o
custo é um `UPDATE`.

Fecha `status = 'ERRO'`, `fim = now()`, `detalhe_erro` com `origem = 'varredura'` e há quanto tempo a
Execução estava aberta.

**Guarda contra configuração incoerente**, que é o dano real (massa não é):

```
pior_legitimo := 3 × (2 × max(relatorio.tempo_estimado_segundos) + 120)
se LIMITE_ORFA < pior_legitimo  →  falha a task, não fecha nada
```

Uma DAG vermelha é visível e reversível; uma tabela de `ERRO` terminal não é. Isso cobre o caminho
inverso da guarda do cadastro, que valida o cadastro e não vê a variável de ambiente mudar.

**Quem vigia o vigia**: métrica `varredura_idade_segundos` no painel-resumo. O `DeadlineAlert`
nativo foi recusado porque o aviso moraria na UI do Airflow, fragmentando a tela única que existe
por não haver canal de notificação.

### 11. Agendamento e fábrica de DAGs

**Cron no cadastro do Produto**, não do Relatório: a variável real é quando a base de origem fica
pronta, e a origem é o schema do Produto. Escalonamento de uma hora por Produto — Poupança 03:00,
Cliente 04:00, Conta Corrente 05:00, Consórcio 06:00, Empréstimo 07:00.

*Consequência a conhecer:* os Relatórios de um mesmo Produto compartilham frequência
obrigatoriamente. "Deltas diários + base mensal" é inexpressável hoje. Nenhum dos cinco Produtos
precisa disso; o próximo que precisar está diante de decisão de arquitetura, não de exemplo.

**A fábrica lê um arquivo materializado pela API, nunca a API.** Consultar serviço externo no parse é
nomeado pelo próprio Airflow como causa de falha do dag processor, e passado o
`dagbag_import_timeout` **as DAGs somem** sem causa visível. A API escreve um snapshot com a
**interseção cadastro ∩ inventário já resolvida**, o cron do Produto e o `tempo_estimado` de cada
Relatório, e o reescreve a cada mudança de cadastro.

**Snapshot ausente ou corrompido levanta exceção, nunca gera zero DAGs** — zero DAGs é
indistinguível de "nenhum Relatório cadastrado" e passa por normal.

`schedule = CronTriggerTimetable(cron, timezone="America/Sao_Paulo")`, `start_date` timezone-aware
via pendulum, `catchup=False` **declarado na DAG** mesmo já sendo default de configuração,
`max_active_runs_per_dag = 1`, e `PYTZDATA_TZDATADIR=/usr/share/zoneinfo` na imagem do Airflow.

Um Relatório cadastrado às 10h aparece em minutos e **roda amanhã**. Um Relatório removido do
cadastro, ou cujo bean saiu da imagem, some do snapshot e a DAG desaparece — não fica órfã.

**Concorrência por pool dedicado** aos `DockerOperator`, começando em 4 slots. Limite por DAG não
compõe; `parallelism` global contaria tasks que não sobem container. **O `minimumIdle` do HikariCP
tem default igual ao `maximumPoolSize`**, então o pool do processador precisa ser fixado em **2** —
senão dez containers ociosos seguram cem conexões.

### 12. Contrato do Starter e a SPI

**Um step tasklet, uma passada.** O fill do Jasper é *pull* e o chunk do Spring Batch é *push*: os
dois não compõem. O Starter envolve a leitura da origem num `JRDataSource` que, a cada linha que o
Jasper puxa, escreve também a linha correspondente do `.csv.gz`. Isso dá uma leitura só e **garantia
estrutural de que PDF e CSV vieram das mesmas linhas**.

A SPI é **um bean por Relatório**:

```
codigo()                 -> "POUPANCA-0001"
jrxml()                  -> recurso no classpath do módulo
consulta()               -> SQL + parâmetros
mapear(row)              -> campos do datasource do Jasper
rotulos()                -> List ordenada, nunca Map iterado
tempoEstimadoSugerido()  -> opcional
```

**O inventário é a enumeração desses beans** — declarar e poder executar são a mesma coisa. Um
arquivo de registro poderia listar Relatório cuja classe não existe, e o inventário herdaria a
divergência.

**O Starter faz**: ler a entrada; extrair o `traceparent` e abrir o span raiz (a JVM não lê
`TRACEPARENT` de variável de ambiente sozinha); selecionar o bean; calcular o `hash_definicao`;
**detectar zero linhas antes do fill**; decorar o `JRDataSource` com a escrita do CSV; preencher com
`JRVirtualizer`; gravar os Artefatos; calcular SHA-256; gravar a transição terminal guardada;
timeout interno; `System.exit(...)`; e o modo `--publicar-inventario`.

**O módulo fornece**: beans, JRXML, fontes e imagens. Um pacote por Relatório.

**Imposto pelo Starter**: step single-thread, sem `TaskExecutor` e sem particionamento — o
`ResourcelessJobRepository` não é thread-safe e um módulo que adicionasse paralelismo corromperia
metadados em silêncio.

**Tempo estimado é dado de cadastro**, não de código: depende do volume daquele ambiente e muda sem
que o código mude. O bean só **sugere**.

**A leitura precisa realmente transmitir.** O pgjdbc só ativa cursor com autocommit desligado,
`TYPE_FORWARD_ONLY`, statement único e `fetchSize > 0` — faltando qualquer uma, ele **degrada em
silêncio** e bufferiza o `ResultSet` inteiro, produzindo o OOM que o virtualizer existe para evitar,
sem sintoma até acontecer.

### 13. Os cinco Produtos e os dez Relatórios

Cada Produto tem schema transacional **autossuficiente** — sem junção com outro Produto, porque a
credencial não alcança — e dois Relatórios: um analítico e um sintético denso.

| Código | Natureza | `E` sugerido |
|---|---|---|
| `POUPANCA-0001` — Movimentação Diária por Agência | analítico, alto volume | 240 s |
| `POUPANCA-0002` — Posição Consolidada de Saldos e Remuneração | sintético; **prova a fonte não embutida** | 30 s |
| `CLIENTE-0001` — Base Cadastral Completa | fotografia diária da base inteira | — |
| `CLIENTE-0002` — Distribuição da Base por Segmento e UF | sintético | — |
| `CONTACORRENTE-0001` — Resumo Diário por Conta | **o maior do sistema**, ~300 mil linhas | — |
| `CONTACORRENTE-0002` — Posição de Cheque Especial e Tarifas por Agência | sintético | — |
| `CONSORCIO-0001` — Posição Diária de Cotas | analítico | — |
| `CONSORCIO-0002` — Posição dos Grupos e Assembleia do Dia | sintético, com evento datado | — |
| `EMPRESTIMO-0001` — Posição da Carteira de Contratos | analítico, volume plano | — |
| `EMPRESTIMO-0002` — Vencimentos do Dia e Inadimplência por Faixa | sintético, absorve a sazonalidade | — |

Três diretrizes de modelagem saíram daqui e valem para Produtos futuros:

1. **"Todo lançamento de todas as contas" é extração de dados, não relatório.** Um relatório é
   agregado ou recortado. É a contenção mais barata do risco de exportação sem teto, porque atua
   antes de qualquer limite.
2. **Evento de ciclo próprio cabe dentro de um relatório diário como coluna datada** — e a linha sem
   o evento aparece zerada, não ausente, para continuar dizendo algo.
3. **Pico de dados não precisa virar pico de relógio**: a sazonalidade vai para o Relatório cuja
   duração é dominada por custo fixo.

**A prova da fonte não se repete.** Ela vive no `POUPANCA-0002` e guarda o empacotamento, não o
comportamento do Jasper. **Nenhum Produto exercita `SEM_DADOS` naturalmente** — o estado fica
coberto apenas por teste, e isso precisa estar escrito para ninguém supor que a produção o exercita.

### 14. Exportação sob demanda

**Síncrona.** Assíncrono não resolveria o problema que o motivou: com a exportação na mesma JVM da
API ([ADR 0002](adr/0002-desserializacao-java-do-jasperprint.md)), `202` + polling mudaria **quando**
o trabalho acontece, não **onde** — o pico de heap é idêntico. E cobraria armazenamento temporário
com TTL e autorização própria, contrato dobrado e uma segunda máquina de estados.

```
autorizar (claim, sem I/O)
  -> adquirir semáforo (espera limitada, depois 503)
  -> buscar o Artefato no repositório
  -> conferir SHA-256
  -> desserializar
  -> exportar
  -> liberar semáforo
```

**O semáforo é adquirido antes de buscar o objeto** — conferir o hash já exige os bytes. `N` sai de
**medição**, não de escolha. Semáforo cheio → espera limitada, depois `503` com `Retry-After`, e o
tempo de espera conta **dentro** do timeout de exportação.

**O CSV fica fora do semáforo.** Ele não desserializa nada: a API busca e transmite, com
`Content-Encoding: gzip`, sem os bytes passarem pelo heap. O SHA-256 continua sendo conferido.

Isso **dissolve** a pergunta sobre autorizar no pedido ou na entrega — não há dois instantes, nem
link temporário sobrevivendo à revogação.

*Risco aceito:* **não há teto de exportação**. O modo de falha está nomeado — `OutOfMemoryError` na
JVM da API, sem isolamento, alcançável por **uso ordinário** (um RELATOR exportando PDF do
`CONTACORRENTE-0001`). A contenção escrita originalmente ("alerta no Grafana") erodiu quando os
alertas ficaram sem canal de notificação. Os números do k6 deixam de ser conforto e passam a ser a
única defesa.

### 15. Formatos

**XLSX sai do mesmo `.jrprint` paginado**, com configuração de exporter aplicada pela API a toda
exportação: `onePagePerSheet(false)`, `removeEmptySpaceBetweenRows(true)` e
`net.sf.jasperreports.export.xls.detect.cell.type=true`.

**A regra da descrição inicial está reescrita**: de *"mitigado desprezando a paginação quando o
formato for XLSX"* para *"mitigado por configuração do exporter"* — `isIgnorePagination` atua no
**fill**, e no momento da exportação já é tarde.

A configuração vive no **código da API**, não no JRXML: o critério é o que acontece por omissão. Com
a linha de base no JRXML, um Relatório novo cujo autor esqueceu produz planilha ruim e ninguém
percebe.

**Dois prints foram recusados**: o `JRDataSource` é consumido uma vez, então dois fills exigiriam
segunda leitura (reintroduzindo a divergência eliminada por construção) ou materializar linhas em
memória — exatamente o que o virtualizer existe para não fazer.

O residual — grid do Excel derivado de coordenadas, cabeçalho repetido — **conserta-se na origem**:
JRXML com **bandas alinhadas numa grade comum** é requisito funcional, não estético, e os relatórios
de exemplo de cada Produto o demonstram.

**Contrato do CSV**:

| | |
|---|---|
| Separador | `;` |
| Encoding | UTF-8 **com BOM** |
| Decimal | vírgula |
| Data | `dd/MM/yyyy` |
| Terminador | CRLF |
| Quoting | só quando necessário; aspas duplicadas para escapar |
| Nulo | campo vazio |
| Cabeçalho | **rotulado**, declarado no bean |
| Colunas | exatamente os campos de `mapear(row)`, na ordem declarada |
| Compressão | `.csv.gz` sempre |

**A coerência é a decisão, não cada item**: `;` com decimal em ponto faria o Excel pt-BR abrir as
colunas certas e tratar todo número como **texto**.

*Riscos aceitos:* sem regra de derivabilidade e sem aviso na UI, a divergência PDF × CSV não é
prevenida nem explicada onde é encontrada. A regra — *PDF, XLSX e DOCX são a visão formatada; CSV é
o dataset* — vive na especificação e na **descrição do endpoint no OpenAPI**, que é o único lugar
onde ela aparece para quem integra. Não é verbosidade a limpar.

### 16. Identidade e autorização

**Perfil é realm role** (`realm_access.roles`): `ADMINISTRADOR`, `GERENTE`, `RELATOR` — conjunto
fechado, não administrável. **Role de Relatório é client role de um client dedicado**
(`resource_access.<client>.roles`), no formato `REL_<SIGLA>_<NOME>`, pertencendo a exatamente um
Produto.

O conversor de authorities vive em `relatorios-comum` e lê **as duas claims**. Errar isso não dá
erro — dá autorização silenciosamente vazia.

**Autorização sai só da claim**:

```
roles   := jwt.resource_access.<client>.roles        (zero I/O)
codigos := SELECT codigo_relatorio FROM relatorio_role_relatorio
            WHERE nome_role = ANY(roles)
```

Duas propriedades são o motivo da escolha: **listagem e geração usam a mesma fonte**, logo não
discordam; e **o Keycloak fica fora do caminho quente**, então uma indisponibilidade dele impede
login e refresh mas não impede quem já tem token de listar e gerar.

**Janela de revogação: 300 s.** O endpoint `/revoke` não a encurta — um resource server stateless
valida a assinatura offline. **O TTL é o mecanismo.** Token de usuário já excluído é servido
normalmente até `exp`, deliberadamente.

**ADMINISTRADOR tem bypass** da cadeia, marcado na linha de `download`. Passar pela mesma cadeia
inverteria a hierarquia: quem decide o que ele enxerga passaria a ser o GERENTE. **Bypass é de
alcance, não de limite** — os tetos valem igualmente para ele.

O teto prático é de ~100 roles por usuário, limitado pelo **Tomcat (8 KB)**, não pelo Traefik (1 MiB).
*Risco aceito:* sem guarda contra estouro de cabeçalho, essa falha acontece antes de qualquer código
da aplicação rodar.

**Mediação obrigatória.** O GERENTE nunca recebe credencial do Keycloak. Um service account recebe
`Clients:manage` escopado ao client dedicado, `Groups` por `resourceType` e `Users` derivadas de
membership — **nunca `manage-users`, nunca `manage-realm`**, porque `manage-users` permite resetar a
senha de qualquer usuário do realm, inclusive ADMINISTRADORes.

**Alçada do GERENTE é global.** *Risco aceito*, lateral e não vertical: ele concede acesso a
relatórios de qualquer Produto, mas não alcança ADMINISTRADOR, outro GERENTE, outro client ou reset
de senha. Isso promoveu a auditoria a controle compensatório — e é por isso que **as recusas são
gravadas**. Como o nome da Role carrega a Sigla, alçada por Produto fica acrescentável depois sem
renomear nada.

*Riscos aceitos compostos:* exclusão de RELATOR é **definitiva**, com auditoria apenas do fato, e o
service account é **um só** — o que estreita a camada de contenção desenhada para o caso de um bug
de autorização na rota do GERENTE.

**Árvore de Grupos**: raiz única `/relatorios`, **um nível**, `PENDENTES` e Grupos como irmãos.
Profundidade é recusada porque o Keycloak herda role mappings de pai para filho, mudando alcance
efetivo em silêncio. A planura é **imposta pela mediação**, não convencionada. A raiz não é fronteira
de segurança — o escopo do FGAP é por tipo, não por ramo; ela paga legibilidade e dá à auditoria um
prefixo estável.

**Proteção do `PENDENTES`**: guarda em código na mediação, identificando o grupo protegido como **o
Default Group do realm** — não por nome nem por UUID de configuração, para que rename e rebuild não a
quebrem em silêncio. *Risco aceito*: é a forma denylist, então endpoint novo nasce desprotegido.

**Grupo vazio e Grupo sem Role são normais**; o que é recusado é **vincular alguém a um Grupo sem
Role alguma** — o vínculo remove do `PENDENTES` na mesma operação e entregaria zero relatórios, com o
contador dizendo "resolvido" quando nada foi.

**Cadastro público**: `PENDENTES` como Default Group, verificação de e-mail **obrigatória**, e a
listagem do GERENTE **filtrando `emailVerified`** — porque Default Group é aplicado na criação e a
required action bloqueia só o login. Sem restrição de domínio (RELATOR só existe por cadastro
público, então allowlist não teria porta dos fundos), sem e-mail de aviso, sem expiração.

**A API não distingue "aguardando vínculo" de "vinculado sem Relatório"** — os dois produzem claim
vazia. Quem diagnostica é o GERENTE, pelas telas que consultam a Admin API ao vivo.

**Sessão e exposição**: SPA puro com RP-initiated logout, sem BFF — back-channel logout é impossível
num SPA. Exposição do Keycloak por **allowlist** no Traefik (falha fechada: rota administrativa nova
numa versão futura nasce bloqueada), com a API falando com a Admin API pela **rede interna** — sem
isso o bloqueio de `/admin/` mataria a mediação junto. Troca de senha no Account Console enxugado,
porque tela própria exigiria dar à aplicação a capacidade de redefinir senha. Sem limite de sessões
concorrentes. **O Keycloak não entra no readiness.**

### 17. Desserialização do `.jrprint`

Registrado no [ADR 0002](adr/0002-desserializacao-java-do-jasperprint.md).

O trade-off original é **reafirmado com a justificativa trocada**. A original — "o arquivo vem do
módulo, logo é confiável" — é falsa: o arquivo vem do **bucket**. A verdadeira é que o atacante
relevante, quem compromete um processador, **já tem a base transacional de um Produto inteiro** —
RCE na API é escalada modesta a partir daí, não o salto de "nada" para "tudo".

| Camada | Estado |
|---|---|
| Formato | `.jrprint` serializado — classe de ameaça viva |
| `ObjectInputFilter` | allowlist **por pacote** (`net.sf.jasperreports.**`, `java.**`, `!*`) + limites do JEP 290 |
| Isolamento | **nenhum** — mesma JVM da API |
| SHA-256 | conferido antes de desserializar; não cobre processador comprometido |
| Prefixo por Produto no repositório | inexistente |

O `.jrpxml` dissolveria a classe de ameaça e foi recusado por fidelidade e custo. **Sobra uma defesa
efetiva: manter o JasperReports atualizado — e isso é manual.** A allowlist por pacote não barra
gadget interno ao Jasper, que é exatamente a forma do CVE-2026-6009.

### 18. Versionamento da definição

**A promessa é registrar, não avisar.** A Execução grava `hash_definicao` (SHA-256 de JRXML +
consulta + rótulos) e `imagem_origem`. A tela do relator não muda.

**O hash responde *se*; o git responde *o quê*.** Decompor em vários hashes foi recusado porque hash
só sabe dizer "diferente" — quem responde o quê é o `git diff` entre os dois commits. Por isso
`imagem_origem` não é acompanhante: sem ele o hash aponta para lugar nenhum.

**Quem calcula é o container**, dos próprios beans, não o inventário. Ler de `jrxml_publicado`
gravaria o que ele *alega*, e uma imagem subida sem rerodar `--publicar-inventario` faria o histórico
mentir em silêncio. Calculando, divergir do inventário **prova** que ele está obsoleto: log,
métrica `inventario_divergente`, e **o job segue**.

A entrada precisa ser **canônica**: ordem fixa dos rótulos (a declarada no bean), encoding fixo, SQL
literal. `mapear(row)` **fica fora** — é método, não dado; a cobertura vem de `imagem_origem`.
*Risco registrado:* mudança apenas no mapeamento aparece no commit, nunca no hash.

**Histórico imutável**: nada reprocessa sozinho depois de um deploy. Reprocesso automático faria de
um deploy um destruidor de histórico, já que `reprocessar` apaga a Execução anterior.

*Diretriz:* mudança que altera o **significado** do relatório é Código novo, não versão nova.

### 19. Contrato de erro e Correlation ID

**RFC 9457**, não 7807 — a 7807 foi obsoletada, e o Spring implementa a 9457 nativamente. Schema
próprio não seria escolha limpa: o framework já emite `ProblemDetail` sozinho, e o resultado seriam
**dois formatos** na mesma API.

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

`type` é URN **não dereferenciável**. O "botão para copiar JSON" não entra no contrato: o corpo já é
JSON, então o botão copia a resposta verbatim.

| Código | HTTP | Natureza |
|---|---|---|
| `ARTEFATO_ACIMA_DO_LIMITE` | 409 | permanente — repetir não adianta |
| `EXPORTACAO_INDISPONIVEL` | 503 + `Retry-After` | transitória — repetir é o certo |
| `ARTEFATO_INTEGRIDADE_DIVERGENTE` | 409 | SHA-256 não bate |
| `ARTEFATO_CLASSE_NAO_PERMITIDA` | 409 | `ObjectInputFilter` recusou |
| `EXECUCAO_SEM_DADOS` | 409 | Execução existe, não gravou Artefato |
| `EXECUCAO_NAO_CONCLUIDA` | 409 | `EM_PROCESSAMENTO` ou `ERRO` |
| `ARTEFATO_EXPIRADO` | 410 | houve arquivo, não há mais |
| `SEM_PERMISSAO_PARA_RELATORIO` | 403 | genérico **por decisão** |
| `ROLE_FORA_DO_PADRAO` | 422 | nome fora de `REL_<SIGLA>_<NOME>` |
| `ROLE_MISTURA_PRODUTOS` | 422 | Role atravessaria Produtos |
| `ALVO_FORA_DA_SUBARVORE` | 403 | mediação: alvo fora dos grupos de relatório |
| `USUARIO_NAO_E_RELATOR` | 422 | mediação sobre Perfil indevido |
| `VINCULACAO_INCOMPLETA` | 500 | entrou no Grupo, não saiu do `PENDENTES` |
| `VERBO_INDEVIDO_USE_REPROCESSAR` | 409 | `refazer` num par ocupado |
| `VERBO_INDEVIDO_NADA_A_DESTRUIR` | 409 | `reprocessar` num par já livre |
| `REPROCESSAMENTO_SEM_MOTIVO` | 422 | validação; o motivo vai para a auditoria |

**As duas primeiras são opostas e se confundem.** Trocá-las na UI produz usuário insistindo no que
nunca passa e desistindo do que passaria.

**`SEM_PERMISSAO_PARA_RELATORIO` é genérico por decisão**: quatro situações produzem a mesma saída —
sem Role, acesso revogado com token ainda válido, aguardando vínculo, e vinculado a Grupo sem
Relatório. A UI orienta a refazer login, que resolve a segunda.

**"Sem acesso a nenhum Relatório" não é erro** — é estado, e leva à página dedicada. Lista vazia não
é modelada como `403`.

**A regra do documento sobre telemetria está reescrita**: ~~"SDK do OpenTelemetry é desabilitado nos
testes"~~ → **SDK ligado em todo ambiente; nos testes, com exportador `none`**. Com o SDK desligado
não há span, o MDC fica vazio, e **todo cenário Gherkin de Correlation ID exercitaria o fallback** —
o caminho de produção nunca seria testado. **Correlation ID é sempre o traceId.**

No batch, o `traceparent` injetado pelo Airflow vira o span raiz por código do Starter; sem ele, o
Starter abre span novo e segue. *Risco aceito:* o Correlation ID **nasce no container**, então a
linha aberta em T1 fica nula até ele gravar — e permanece nula se ele nunca subir. Contenção: o
`dag_run_id` é gravado em T1.

**Nunca vaza**: stack trace, SQL, nome de schema, credencial, hash esperado ou obtido, chave do
objeto, corpo de erro da Admin API, nome de client, nome interno de permissão FGAP.

**Exceção conhecida à garantia "todo erro tem Correlation ID"**: JWT acima do limite de cabeçalho do
Tomcat é rejeitado antes de qualquer filtro — sem MDC, sem corpo padronizado. Documentada, não
implícita.

*Risco aceito:* batch e API têm **vocabulários separados** — o batch usa `detalhe_erro.codigo`.

### 20. Observabilidade

Logback com structured logging; caminho do log **app → OTLP → Collector → Graylog** (OpenTelemetry
gRPC Input). Métricas por **push OTLP ao Collector**, com o Prometheus fazendo scrape do Collector.
Traces via Collector → Jaeger (OTLP nativo). Atenção à colisão da porta 4317 no Compose.

**Regra de label**: *um label só é permitido se seu conjunto de valores for limitado por cadastro,
nunca por uso.*

| | |
|---|---|
| Permitidos | `produto`, `codigo_relatorio`, `status`, `formato`, `tipo`, `codigo`, `origem_encerramento`, `motivo`, `desfecho`, `tabela` |
| Proibidos | `data_referencia`, `usuario`, `correlation_id`, `dag_run_id`, chave do Artefato |

Cruzar Código × formato × status dá alguns milhares de séries — o Prometheus lida com milhões. O
problema é label que cresce com o uso.

**Coleta**: `coleta_duracao_segundos` (mede `fim − inicio_processamento`, a mesma janela do limiar de
`ALERTA`), `coleta_partida_segundos` (`inicio_processamento − inicio`), `coleta_execucoes_total` (com
`origem_encerramento` distinguindo container, callback e varredura), `coleta_tentativas_total`,
`coleta_linhas_processadas`, `artefato_tamanho_bytes`, `execucao_encerramento_perdido_total`,
`varredura_idade_segundos`, `inventario_divergente`.

**API**: `http_server_requests`, `exportacao_duracao_segundos` (por formato — PDF/XLSX/DOCX
desserializam, o CSV não; medi-los juntos esconde o que importa para dimensionar heap),
`exportacao_semaforo_ocupacao`, `exportacao_semaforo_espera_segundos`, `exportacao_recusas_total`,
`download_total` (com `via_bypass`), `download_apos_expurgo_total` (com desfecho `entregue` |
`expirado` — a **única** medida observável da latência do scanner), `erro_total`.

**Capacidade**: `bucket_objetos_total`, `bucket_bytes_total`, `tabela_linhas`,
`readiness_transicoes_total`, `series_total`.

*Riscos aceitos:* a guarda de cardinalidade é **documental**, não executável; e **os alertas não
notificam ninguém**. O segundo é composto e maior que si mesmo — três riscos aceitos em outros pontos
eram contidos por "alerta no Grafana", e todos passam a depender de alguém abrir a tela.

**A contenção é o painel-resumo**, que deixa de ser organização visual e vira mecanismo: destino
padrão de quem abre o Grafana, respondendo "algo precisa de atenção agora?" em dez segundos —
encerramento perdido, `ALERTA` recorrente, artefato acima do teto, Execuções fechadas pela varredura,
Coletas do dia, idade da varredura e contagem de séries.

### 21. Health

| | |
|---|---|
| `liveness` | apenas `LivenessState` — **nunca** depende de recurso externo |
| `readiness` | `ReadinessState` **+ PostgreSQL**; MinIO e Keycloak fora |
| Indicador do banco | DOWN só após **N falhas consecutivas**; UP na primeira que passar |
| Grupo `dependencias` | PostgreSQL, repositório, árvore de Grupos — consumido por Prometheus/Grafana, **não** pelo Traefik |
| Exposição | porta 8080, allowlist no Traefik, exposição default do Spring como segunda camada |

Incluir o PostgreSQL é ato deliberado — o default do Spring Boot não põe indicador algum nos grupos.
*Risco aceito*: numa queda do banco todas as instâncias saem juntas e o usuário recebe `503` opaco do
Traefik em vez de erro RFC 9457 com Correlation ID.

**O amortecimento precisa estar no indicador**, não só no `retries` do Compose: o health check do
Traefik reage à primeira falha. E o `connectionTimeout` do Hikari precisa ser menor que o timeout de
HTTP — senão a instância cai por timeout sem a falha jamais alcançar o indicador.

MinIO fora do readiness preserva a **degradação parcial**: a listagem funciona e a exportação falha
com código do catálogo. Processadores não têm endpoint de health — o sinal deles é o exit code.

### 22. Frontend

| | |
|---|---|
| Drop-down | **lista única filtrável**, não selects encadeados nem árvore |
| Rotas | áreas lazy com **`canMatch` no nó pai** |
| Download | `HttpClient` com `responseType: 'blob'` |
| Erro | o `detail` vem da API; o front mapeia `codigo` só para **comportamento** |
| Estado | serviço `providedIn:'root'` com signals e `httpResource`, mais `SessionStore` |

A lista única ganha porque a resposta vem numa chamada só (~70 linhas), os **quatro** estados de item
precisam ser comparáveis lado a lado, e hierarquia de três níveis sobre um punhado de linhas é
cerimônia.

`canMatch` no nó pai é a forma **allowlist**: tela nova dentro da área herda proteção. **Mas o guard
não é controle de acesso** — quem autoriza é a API, e o preloader do Angular baixa chunk sem rodar
guard. O ganho é bytes na navegação, não segurança. Um shell por Perfil na raiz foi recusado porque
nada impede um usuário de ter dois Perfis.

Blob porque um `<a download>` não manda `Authorization` e exigiria URL assinada — exatamente o que a
decisão de exportação síncrona fechou. Consequências: `URL.revokeObjectURL` depois do uso; o arquivo
passa **inteiro** pela memória do navegador; e a espera precisa de estado visível, porque sem
progresso nativo e com `503` possível uma tela parada é indistinguível de travada.

**O cliente não refiltra a listagem** — a API já filtrou pela claim.

Telas: **`/relatorios`** (listagem filtrável + página dedicada de "sem acesso"); **`/gestao`** (fila
do `PENDENTES`, vinculação, Grupos e Roles, usuários ao vivo); **`/admin`** (cadastro de Produto e
Relatório, inventário publicado, histórico de Execuções com `refazer` e `reprocessar` como **dois
botões distintos**, histórico de Download, auditoria, usuários GERENTE/ADMINISTRADOR).

O selo de expirado diz a **data real**, e o botão **não** é desabilitado pela marcação. Correlation
ID visível e copiável em toda tela de erro. A janela de 300 s não tem representação na tela —
inventar um aviso sugeriria um controle que não existe.

### 23. Contrato REST

Prototipado antes do código em `docs/mapa/prototipos/openapi-descartavel.yaml`; substituído depois
por SpringDOC OpenAPI. Dezesseis caminhos.

**Duas formas de endereçar uma Execução, de propósito.** A chave natural
(`/relatorios/{codigo}/execucoes/{data}`) endereça a Execução **disponível** daquele par; o
identificador opaco (`/execucoes/{id}`) endereça **uma linha específica**, inclusive tentativas que
falharam. Não é duplicação — a chave natural deixou de ser única quando o índice virou parcial.

**Formato como parâmetro de consulta**, não sufixo de caminho: uma operação, com o catálogo de erro
anexado uma vez. **Uma listagem filtrada**, não três endpoints em cascata.

**Duas assincronias diferentes**: a exportação é síncrona (`200` com os bytes), mas `refazer` e
`reprocessar` respondem `202`, porque a Coleta é assíncrona por natureza. As duas telas não podem
parecer a mesma coisa.

**Login, logout e troca de senha não têm endpoint** — o SPA fala direto com o Keycloak.

O que a substituição pelo SpringDOC precisa preservar: a descrição da exportação (único lugar onde a
divergência PDF × CSV aparece para quem integra), a distinção `409` × `503` com exemplos, a nota de
que `SEM_PERMISSAO_PARA_RELATORIO` é genérico por decisão, e a exceção conhecida do cabeçalho acima
do limite.

### 24. E-mail

**Só o Keycloak dispara, e só dois e-mails**: verificação de endereço e redefinição de senha. **A API
não fala SMTP** — não ganha modo de falha novo nem entra no readiness.

*Risco aceito:* **Mailpit em produção**. Ele **captura em vez de entregar**, então o cadastro público
deixa de ser autoserviço: um operador abre a UI, acha o link e repassa. Três consequências que dois
outros pontos já tinham criado e ninguém previu — sem verificar, o candidato fica fora da listagem e
**invisível** ao GERENTE; quem esquece a senha não tem caminho de volta, nem próprio nem
administrativo; e a **UI do Mailpit vira porta de tomada de conta** (links em texto claro), entrando
na allowlist do Traefik com autenticação própria e volume persistente.

O tema de e-mail muda de público: quem lê é o operador varrendo a caixa, então o assunto carrega
**para quem é** e **qual a ação**, não marca.

### 25. Deploy, CI e capacidade

**Rollback não é procedimento, é propriedade das migrações**: toda migração é **aditiva e compatível
com a imagem anterior** — coluna nova sempre nula, nunca `DROP` nem rename no mesmo release. "Voltar"
é redeployar o SHA anterior **sem tocar no banco**. Renomear coluna vira dança de dois releases.
Restore de banco como rollback foi recusado por transformar perda de dado em rotina.

**`deploy.sh <sha>`**, idempotente e versionado, com o SHA como **parâmetro obrigatório em vez de
disciplina**:

```
1. checkout do SHA + build das imagens na VM
2. Flyway por natureza de schema
3. --publicar-inventario por módulo processador
4. restart, respeitando o readiness amortecido
5. confere o que não automatiza, e falha alto
```

O que ele confere sem automatizar: chave do AIStor válida, árvore de Grupos com `PENDENTES` como
Default Group, Mailpit de pé com volume persistente, allowlist do Traefik.

**Upgrade do Keycloak tem lista própria de reaplicação** — o `--import-realm` é **pulado** em realm
existente: allowlist do Traefik, permissões de FGAP e escopo do service account, Default Group,
features do realm e Account Console enxugado, tema de e-mail. **O upgrade dispara o E2E completo**,
porque nenhum desses itens é verificável por leitura de configuração.

**CI**: runners `ubuntu-24.04-arm` (arquitetura de produção, Docker sem DinD), `pr` = unidade +
integração, `merge` = + aceitação + E2E + publicação do artefato de cobertura, k6 agendado ou sob
demanda. **Nenhum segredo** — os Testcontainers sobem MinIO AGPL congelado com tag fixa. Cache de
Maven pelo `setup-java`; imagens Docker não.

*Risco aceito:* **o CI para no teste** — não há registry, e as imagens são construídas na VM. Isso
**agrava** a divergência de versão do Jasper já aceita, porque não há momento único de build, e é o
que torna o SHA fixado no deploy um requisito, não uma boa prática.

**Capacidade**: uma VM só, com Traefik, Keycloak, API, Airflow, Mailpit, observabilidade, PostgreSQL
e repositório no mesmo host. *Risco aceito*, e **não independente do de exportação sem teto**: com o
OOM da API alcançável por uso ordinário, pôr banco e repositório no mesmo host faz o modo de falha da
aplicação alcançar os dados. Duas mitigações que não custam VM: **limites de memória por container**
no Compose, e **Traefik por arquivo estático** em vez de descoberta via Docker — o Airflow precisa do
socket, o Traefik não.

*Risco aceito:* **backup existe, restore não é ensaiado**. Uma coisa cai de graça: divergência entre
o backup do banco e o do repositório **degrada em vez de quebrar**, porque a exportação já tenta
buscar o que a listagem marcou como expirado.

Números fixados: `CLIENTE-0001` e `CONSORCIO-0001` são fotografias diárias da base inteira, então com
retenção de 7 dias são **sete cópias de cada** no bucket a qualquer momento. Pool de Coletas em 4
slots, a calibrar. `download` e `auditoria_admin` crescem indefinidamente.

---

## Decisões de teste

### O que faz um bom teste aqui

Teste comportamento externo observável, nunca implementação. A régua deste projeto é mais específica
do que a máxima geral, porque o mapa inteiro foi construído catando um modo de falha recorrente: **o
falso verde**.

1. **Asserte no efeito, não na configuração.** A degradação do pgjdbc para buffer completo é do
   driver: uma asserção sobre `fetchSize` passa com o bug presente. Só o heap apertado contra volume
   que o excede prova que a leitura transmite.
2. **Um teste que passa pelo motivo errado é pior que teste ausente.** `/actuator/env` devolve `401`,
   não `404` — um teste "env não responde" passaria mesmo se a exposição estivesse aberta.
3. **Caminho feliz não basta quando o modo de falha é o silêncio.** O conversor de authorities
   quebrado produz autorização **vazia**, não exceção: um teste "403 quando não autorizado" passa com
   ele quebrado. É preciso o caso positivo.
4. **Testar que algo NÃO acontece é tão obrigatório quanto o inverso.** Divergência de versão do
   Jasper precisa **exportar** e alertar; `SEM_DADOS` precisa não gravar Artefato **nenhum**;
   inventário divergente precisa não falhar o job.
5. **Quando o comportamento é "alerta sem recusar", o assert é na métrica.** Verificar que o job
   passou não distingue isso da comparação nem existir.
6. **Teste com as credenciais reais.** Rodar como superusuário faz o isolamento por `GRANT` passar
   verde em teste e falhar em produção.
7. **Presença não é execução.** `@Disabled` satisfaria "o teste existe" sem provar nada.

### As camadas, definidas pela infraestrutura necessária

A fronteira entre integração e aceitação não se resolve por vocabulário — as duas usam Gherkin. Ela
se resolve por **o que precisa estar de pé**, que é verificável e dá custo de CI previsível.

| Camada | O que precisa estar de pé | Onde roda |
|---|---|---|
| unidade | nada — só a JVM | PR |
| **integração** | Testcontainers: PostgreSQL, repositório, Keycloak conforme o caso; um módulo por vez | PR |
| aceitação | stack do Compose, exercitada pela API | merge |
| E2E | Playwright (navegador) e Newman, contra Traefik e Keycloak reais | merge |
| carga | k6 | fora do gate |

### As costuras

**A costura principal é a camada de integração**, e é a mais alta que serve ao caso: quase todo o
comportamento da Coleta cabe nela.

- **Coleta**: o job roda **in-process** com `JobOperatorTestUtils` (que substituiu
  `JobLauncherTestUtils` no Spring Batch 6) contra Testcontainers de PostgreSQL e do repositório.
  Semear um schema transacional, rodar a Coleta e verificar Artefato e linha de metadados **não
  exige Compose nem Airflow**. A Coleta é muito mais barata de testar do que o enunciado sugeria.
- **API**: exercitada por HTTP sobre os mesmos containers, incluindo Keycloak quando a autorização
  faz parte do cenário.
- **Isolamento**: singleton com `@ServiceConnection`. **Reuso de container é armadilha** — a própria
  documentação do Testcontainers diz que não serve para CI.

**Nenhuma costura nova é criada.** As que existem são a SPI do Starter (bean por Relatório, já
projetada para substituição), o `JRDataSource` decorado, a porta S3 (o código fala S3 puro, nunca API
de fornecedor) e a mediação da Admin API.

**Só o que a costura de integração não alcança sobe para aceitação**: o contrato com o Airflow (exit
code, retry ponta a ponta, conversão de fuso), os fluxos de e-mail com Mailpit de pé, e a allowlist
do Traefik.

**O H2 está fora da stack**, por evidência empírica: em `MODE=PostgreSQL` ele aceita `jsonb`,
converte para `json` e grava string escapada onde o PostgreSQL grava objeto — teste verde, produção
divergente, zero sinal. Também quebram `ON CONFLICT ... DO UPDATE`, `->>`, `@>`, `jsonb_*`,
`RETURNING`, `text[]`, GIN, `timestamptz` e plpgsql. Testcontainers custam ~1,5–2,0 s com imagem em
cache no ARM64.

### Onde os `.feature` vivem

**No código**, onde o Cucumber os executa. A especificação carrega a **lista de cenários
obrigatórios** — sem duplicação e sem deriva, porque um `.feature` fora do runner é documentação que
apodrece.

### Cobertura: não-regressão mais a lista

O JaCoCo mede sempre; o gate exige que a cobertura **não caia** em relação à main. **Nenhum número
absoluto** — os tickets não pediram "mais testes", nomearam **cenários**, várias vezes com a
justificativa *"é o único sinal que existe"*. Testar o cursor com heap apertado cobre poucas linhas;
vinte getters cobrem muitas. Uma meta absoluta é atingível escrevendo exatamente os testes errados.

A linha de base vem do artefato do JaCoCo publicado no merge; quando ele falta, o job **roda a main
uma vez** para regenerá-lo, e o fallback é **barulhento** — regenerar em silêncio faria um artefato
expirado transformar o gate em enfeite.

### A lista de cenários obrigatórios é o gate real, e é executável

Cada item abaixo é um identificador; cada identificador é um teste marcado; um passo do CI afirma que
todos **rodaram e passaram**. A conferência é nas duas direções: id sem teste pega cenário removido
em silêncio; teste marcado sem id pega cenário sem justificativa — que é o que preserva a razão de a
lista existir.

**Fronteira de dados e bootstrap**

- `CO-ISOLAMENTO-CREDENCIAL` — `app_proc_poupanca` **não** consegue ler `transacional_cliente`
- `CO-BOOTSTRAP-ORDEM` — controle → transacionais → `--publicar-inventario` → API
- `CO-CADASTRO-FORA-DO-INVENTARIO` — cadastrar Código ausente do inventário é recusado
- `CO-INVENTARIO-DECLARATIVO` — publicar sem o bean **retira** do inventário, sinaliza o cadastro e
  não apaga nem falha
- `CO-GUARDA-TEMPO-ESTIMADO` — `3 × (2E + 120) ≤ LIMITE_ORFA`: ~3.540 s aceito, acima recusado
- `CO-STEP-SINGLE-THREAD` — teste de arquitetura: nenhum `TaskExecutor` configurado em step

**Ciclo de vida, unicidade e retry**

- `CO-INDICE-PARCIAL-QUATRO-COMBINACOES` — par com `ERRO` aceita; com `SEM_DADOS` aceita; com
  `SUCESSO` rejeita; com `ALERTA` rejeita
- `CO-CORRIDA-ABRIR-EXECUCAO` — dois disparos simultâneos do mesmo par, um falha
- `CO-RETRY-REUSA-LINHA` — três tentativas, uma linha, um único `ERRO` no fim
- `CO-CONTAINER-NAO-GRAVA-ERRO` — container que falha deixa a linha aberta; quem fecha é o callback
- `CO-EXIT-CODE-JOB-FALHO` — job Batch falho sai com código diferente de zero
- `CO-DURACAO-INICIO-PROCESSAMENTO` — `E = 10 s` com partida lenta resulta em `SUCESSO`, não `ALERTA`
- `CO-SEM-DADOS-NADA-GRAVADO` — zero linhas encerra sem **nenhum** objeto no repositório
- `CO-ARTEFATO-PARCIAL` — Coleta interrompida durante a escrita não registra `artefato` nem `SUCESSO`
- `CO-VERBOS-CRUZADOS` — `refazer` em par ocupado e `reprocessar` em par livre são recusados
- `CO-DOWNLOAD-EXECUCAO-NULA` — reprocessar mantém a linha de Download legível com `execucao_id` nulo
- `CO-FUSO-DATA-REFERENCIA` — `logical_date` às 22:00 BRT produz o dia anterior ao de `{{ ds }}` cru

**Coleta e artefatos**

- `CO-CURSOR-HEAP-APERTADO` — leitura com heap apertado contra volume que o excede se bufferizado
- `CO-CSV-MESMAS-LINHAS` — contagem de linhas do `.csv.gz` igual à do `JasperPrint`
- `CO-FONTE-AUSENTE-FALHA` — exportar o relatório real com `ignore.missing.font=false` falha se a
  font extension sair do classpath
- `CO-FONTE-NEGATIVO` — fonte inexistente prova que a propriedade está em vigor
- `CO-HASH-ESTAVEL` — mesmo bean, duas JVMs, mesmo `hash_definicao`
- `CO-INVENTARIO-DIVERGENTE-NAO-FALHA` — hash divergente termina em `SUCESSO` **com a métrica
  incrementada**
- `CO-DIVERGENCIA-VERSAO-JASPER` — Artefato de versão diferente **exporta** e alerta

**Exportação**

- `CO-INTEGRIDADE-SHA256` — `.jrprint` com hash divergente é recusado
- `CO-OBJECTINPUTFILTER` — classe fora da allowlist é recusada na desserialização
- `CO-VAZAMENTO-SEMAFORO` — cada modo de falha em sequência, e a ocupação volta a zero
- `CO-409-VS-503` — permanente e transitório, um cenário cada
- `CO-CSV-FORA-DO-SEMAFORO` — CSVs simultâneos passam com o semáforo saturado por PDFs
- `CO-EXPIRADO-QUE-BAIXA` — item marcado como expirado **baixa com sucesso**
- `CO-410-OBJETO-AUSENTE` — `410` só quando o objeto realmente sumiu
- `CO-XAMZ-EXPIRATION` — os dois caminhos (header do servidor e cálculo local)
- `CO-LIFECYCLE-ORFAO` — objeto sem linha em `artefato` é alcançado pela regra de filtro vazio

**Autorização e mediação**

- `CO-CONVERSOR-AUTHORITIES-POSITIVO` — a Role certa **concede**, lendo claim aninhada
- `CO-CONVERSOR-PERFIL-REALM-ROLE` — o Perfil é lido de `realm_access.roles`
- `CO-BYPASS-ADMINISTRADOR` — alcança Relatório sem Role **e** marca o Download como bypass
- `CO-EXCLUSAO-REMOVE-SESSAO` — excluir usuário remove a sessão, e o refresh falha
- `CO-PENDENTES-FILTRA-EMAILVERIFIED` — cadastro não verificado não aparece na listagem
- `CO-VINCULACAO-INCOMPLETA` — entrou no Grupo e a remoção do `PENDENTES` falhou é reportado
- `CO-VINCULO-SEM-ROLE` — vincular a Grupo sem Role é recusado
- `CO-RECUSA-APAGAR-DEFAULT-GROUP` — recusado **pela guarda**, provadamente
- `CO-GRUPO-FILHO-DA-RAIZ` — Grupo criado é sempre filho direto da raiz
- `CO-DEPENDENCIAS-PENDENTES` — o indicador cai quando o `PENDENTES` deixa de ser Default Group
- `CO-CAMINHO-INTERNO-ADMIN-API` — a API alcança a Admin API pela rede interna
- `CO-ALLOWLIST-TRAEFIK-FLUXOS` — login, cadastro, verificação e troca de senha passam pela allowlist
- `CO-CADASTRO-DISPARA-VERIFICACAO` — cadastro público gera o e-mail, verificado no Mailpit

**Erro, health e orquestração**

- `CO-PROBLEM-DETAIL-UNICO-FORMATO` — erro do próprio Spring sai em `application/problem+json`
- `CO-OTEL-SEM-COLLECTOR` — a suíte roda sem Collector algum no ambiente
- `CO-CABECALHO-ACIMA-DO-LIMITE` — rejeitado sem corpo padronizado e sem Correlation ID
- `CO-READINESS-AMORTECIDO` — uma falha isolada não derruba; N consecutivas derrubam
- `CO-LIVENESS-SEM-BANCO` — `liveness` permanece UP com o PostgreSQL parado
- `CO-ACTUATOR-NAO-EXPOSTO` — `env`, `beans` e `heapdump` não respondem
- `CO-DEGRADACAO-MINIO` — readiness UP, listagem funcionando, exportação com erro do catálogo
- `CO-SNAPSHOT-AUSENTE-EXCECAO` — a fábrica **levanta exceção**, não gera zero DAGs
- `CO-FABRICA-SEM-REDE-NO-PARSE` — nenhuma chamada de rede durante o parse
- `CO-FORA-DA-INTERSECAO-SEM-DAG` — nem cadastrado sem bean, nem publicado sem cadastro
- `CO-MIGRACAO-ADITIVA-IMAGEM-ANTERIOR` — migrações do SHA novo, container do SHA anterior

`SEM_DADOS` **não é exercitado por nenhum Produto em produção** — o estado fica coberto apenas por
teste, e esta nota impede que alguém suponha o contrário e afrouxe a cobertura.

### O k6 calibra, não verifica

Fica **fora do gate** por natureza. Ele precisa empurrar até o OOM para estabelecer dois números que
não saem de cálculo e que, sem teto de exportação, são a **única defesa**:

1. o multiplicador entre o tamanho do `.jrprint` serializado e o heap que ele ocupa desserializado;
2. o `N` do semáforo que daí decorre, e o heap da API contra o maior `.jrprint`
   (`CONTACORRENTE-0001`).

O teste de cursor roda com heap apertado **de propósito** — é prova de que a leitura transmite, não
estimativa de heap de produção. Não confundir os dois números.

### Seis verificações manuais contra o AIStor real

O CI roda MinIO AGPL congelado e produção roda AIStor — a mesma forma de problema que fez este
projeto remover o H2, com delta menor mas não nulo. Estas **não são teste automatizado** (o CI não
tem chave de licença, de propósito) e precisam de dono e momento definidos: lifecycle com filtro
vazio expurgando os dois Artefatos na mesma rodada, `x-amz-expiration` no `PutObject`, ausência de
`s3:DeleteObject`, ausência de `s3:ListBucket` na credencial da API, expurgo de objeto órfão, e
imagem ARM64 do AIStor.

---

## Fora de escopo

- **MFA.**
- **Rotação obrigatória da senha inicial do ADMINISTRADOR.**
- **Kubernetes** — produção roda Docker Compose em VMs.
- **Classificação de dados, mascaramento e criptografia em repouso.** Consequência assumida
  explicitamente: `download` e `auditoria_admin` acumulam dado pessoal indefinidamente.
- **Cache de exportação com o binário exportado.** Se voltar, volta como esforço novo.
- **Cancelamento de Execução sob demanda.** Nenhuma tela, endpoint ou Perfil tem essa capacidade, e
  `CANCELADO` sem transição de entrada seria peso morto. Interrupção manual pela UI do Airflow é
  indistinguível de queda de VM e cai como `ERRO` pela varredura. Trazê-lo de volta arrasta endpoint,
  autorização por Perfil e parada de container.
- **Data de competência.** Modelada como uma data só. Se entrar, entra como coluna de metadados,
  nunca como componente do caminho.
- **Espelho do Keycloak no schema de controle.**
- **BFF.** Sem ele, back-channel logout é impossível; a decisão foi consciente.
- **Alçada do GERENTE por Produto.** Acrescentável depois sem renomear nada, porque o nome da Role
  já carrega a Sigla.
- **Retenção por Produto.** Possível via tags de lifecycle, mas custaria `s3:PutObjectTagging` na
  credencial do processador e traria o modo de falha silencioso de objeto sem tag nunca expirar.
- **Retenção de linhas de `execucao`, `download` e `auditoria_admin`.**
- **Teto de exportação, ensaio de restore e segunda VM** — riscos aceitos com modo de falha nomeado.

---

## Notas adicionais

### Onde esta especificação corrige a descrição inicial

| Descrição inicial | Aqui |
|---|---|
| "mitigado desprezando a paginação quando o formato for XLSX" | mitigado por **configuração do exporter** — `isIgnorePagination` atua no fill |
| "SDK do OpenTelemetry é desabilitado nos testes" | **SDK ligado** em todo ambiente, com exportador `none` nos testes |
| "escrita pelos processadores, leitura pela API" | **três escritores** — processadores, Airflow e API (só `download`) |
| "o arquivo vem do módulo, logo é confiável desserializar" | falso — vem do bucket; o trade-off é mantido por **outra** razão (ADR 0002) |
| "`serialVersionUID` não quebra entre versões" | certo pelo motivo errado — a constante é fixa, então divergência falha **em silêncio** |
| RFC 7807 no formato de erro | **RFC 9457**, que a obsoletou |
| Log4j2 na tech stack | **Logback** |
| H2 em modo PostgreSQL nos testes | **Testcontainers**; o H2 saiu por evidência empírica |
| MinIO como repositório | **"compatível com S3"** é o contrato; o `minio/minio` foi arquivado (ADR 0003) |
| Spring Batch 5.x implícito | **Spring Batch 6**, o que muda a API do Starter |
| "o `on_failure_callback` basta para fechar execuções órfãs" | não basta — exige **DAG de varredura** |
| PrimeNG como candidato de UI | **Angular Material** — o PrimeNG v22 deixou de ser MIT |

### Pendências da descrição inicial, todas fechadas

Cadastramento de contêineres novos no Airflow (fábrica de DAGs sobre snapshot); gravação dos
metadados de processamento e de relatório (schema de controle); revisão da Tech Stack; UI de
navegação do drop-down (lista única filtrável); biblioteca de log (Logback); nomes dos módulos;
arquitetura de cada módulo; relatórios de exemplo e seus modelos de dados (dez Relatórios, cinco
schemas, dez JRXML).

### As quatro fases iniciais, entregues e aprovadas

1. Protótipo HTML/CSS/JS descartável — `docs/mapa/prototipos/html/`
2. Swagger descartável — `docs/mapa/prototipos/openapi-descartavel.yaml`
3. Esqueleto Maven multi-módulo compilando — `mvn clean install` verde nos onze módulos
4. Actuator liveness e readiness respondendo UP, provado com PostgreSQL real

Dois defeitos que só a prova revelou, e que valem como aviso permanente: grupos de health escritos em
`management.group` em vez de `management.endpoint.health.group` são **ignorados em silêncio** pelo
Spring (o readiness respondia UP com o banco derrubado); e o `connectionTimeout` default do Hikari
fazia a instância cair por timeout de HTTP **sem a falha jamais alcançar o indicador**.

### O padrão que se repete nas decisões

Vale registrar porque é o critério que resolveu a maioria dos empates, e serve para as decisões que
ainda vão aparecer:

- **Falhar fechado, e preferir barulho a silêncio.** Allowlist em vez de denylist no Traefik e nas
  rotas do Angular; snapshot ausente levantando exceção em vez de gerar zero DAGs; fallback de
  cobertura que anuncia que rodou.
- **Modelagem antes de mecanismo.** Três tensões que pediam mecanismo novo — o maior Produto, o ciclo
  mensal do Consórcio, a sazonalidade do Empréstimo — se resolveram mudando o que o Relatório mede.
- **Alertar sem recusar** quando o trabalho produzido está correto e o que está velho é catálogo:
  divergência de versão do Jasper e inventário obsoleto.
- **Um lugar só para cada verdade.** Sem espelho do Keycloak, sem segundo catálogo de erro no front,
  sem `.feature` fora do runner, sem manifest no bucket duplicando o hash do banco.

### O risco que merece revisão primeiro

Três riscos aceitos se compõem e o resultado é maior que a soma: **não há teto de exportação**, **a
exportação roda na JVM da API sem isolamento** (ADR 0002), e **os alertas não notificam ninguém**. A
contenção escrita para o primeiro era "alerta no Grafana"; o terceiro a esvaziou depois, e ninguém
revisitou o primeiro. O modo de falha resultante é OOM da API alcançável por **uso ordinário**, e com
uma VM só ele disputa memória com o banco e o repositório.

Se algum destes for revisitado, revisite os três juntos.
