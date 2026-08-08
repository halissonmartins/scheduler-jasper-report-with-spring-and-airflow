# PRD — Scheduler Jasper Report

> Documento do eixo **Produto** (P0 do `guias/guia-app-web.md`). Descreve **o que** o
> sistema faz e **por quê**. O **como** — stack, módulos, formatos de arquivo,
> orquestração e infraestrutura — vive em [`arquitetura-inicial.md`](./arquitetura-inicial.md).

| | |
|---|---|
| **Versão** | 2 — revisão de ambiguidades |
| **Status** | Em revisão |
| **Idioma do domínio** | pt-BR. Os termos da seção *Conceitos do domínio* aparecem no código como estão escritos aqui |

---

## 1. Visão geral

O sistema tem duas metades que se encontram num repositório de artefatos:

1. **Coleta** — todo dia, de forma agendada, cada produto tem seus relatórios gerados a
   partir da sua base transacional e gravados já renderizados no repositório, junto com
   os metadados da execução.
2. **Exportação** — sob demanda e de forma síncrona, um usuário autorizado escolhe um
   relatório já coletado e recebe o arquivo no formato que precisa: PDF, XLSX, DOCX ou CSV.

O relatório é **lido da base uma vez** e **exportado quantas vezes for preciso**.

---

## 2. Problema

A base transacional de cada produto só pode ser lida uma vez por dia, por um processo
controlado. Toda solicitação de relatório que vá direto à base transacional concorre com a
operação do produto — e é justamente no fim do mês, quando mais se pede relatório, que a
base está mais carregada. Não existe hoje um lugar onde o dado do relatório já esteja
apurado, congelado por data e pronto para ser entregue.

As consequências, por pessoa:

- **Quem precisa do relatório** não sabe se o dado está disponível, não sabe se o número
  que recebeu ontem é o mesmo de hoje, e depende de alguém para exportar num formato
  diferente do PDF.
- **Quem administra o acesso** não tem como conceder acesso a um conjunto de relatórios:
  concede caso a caso, e a permissão fica dispersa e não auditável.
- **Quem administra o catálogo** não tem um lugar único que diga quais relatórios existem,
  a que produto pertencem e quanto tempo cada um leva para ser apurado.
- **Quem opera** descobre que a apuração falhou quando o usuário reclama. Uma execução que
  travou fica indistinguível de uma que ainda está rodando.

**O que muda com o sistema:** o dado é apurado uma vez por dia, congelado por data de
referência, e a entrega passa a ser um problema de leitura — rápida, repetível, autorizada
e observável.

---

## 3. Usuários-alvo

### 3.1 Personas

| Persona | Quem é | O que precisa | Frequência |
|---|---|---|---|
| **Relator** | Analista de uma área de negócio | Baixar, no formato certo, os relatórios da sua área numa data específica | Diária a semanal |
| **Gerente** | Responsável por uma área | Conceder e revogar acesso a relatórios sem depender de TI | Eventual |
| **Administrador** | Responsável pelo catálogo e pela plataforma | Cadastrar produtos e relatórios, gerir usuários administrativos, diagnosticar e refazer apurações | Eventual |

### 3.2 Perfis

Três perfis, **conjunto fechado e definido em código** — não são administráveis pela
aplicação. Um usuário tem exatamente um perfil.

| Ação | ADMINISTRADOR | GERENTE | RELATOR |
|---|:---:|:---:|:---:|
| Cadastrar/remover produto | ✅ | ❌ | ❌ |
| Cadastrar/remover relatório | ✅ | ❌ | ❌ |
| Cadastrar/remover usuário ADMINISTRADOR e GERENTE | ✅ | ❌ | ❌ |
| Remover usuário RELATOR | ✅ | ✅ | ❌ |
| Cadastrar/remover role de relatório | ❌ | ✅ | ❌ |
| Vincular role de relatório a relatório | ❌ | ✅ | ❌ |
| Cadastrar/remover grupo | ❌ | ✅ | ❌ |
| Vincular role de relatório a grupo | ❌ | ✅ | ❌ |
| Incluir/remover usuário em grupo | ❌ | ✅ | ❌ |
| Listar relatórios disponíveis | ✅ *(todos)* | ❌ | ✅ *(só os permitidos)* |
| Exportar e baixar relatório | ✅ *(todos)* | ❌ | ✅ *(só os permitidos)* |
| Cancelar execução em andamento | ✅ | ❌ | ❌ |
| Solicitar reprocessamento forçado | ✅ | ❌ | ❌ |
| Consultar histórico de downloads | ✅ | ❌ | ❌ |
| Autocadastrar-se | ❌ | ❌ | ✅ |
| Trocar a própria senha e recuperá-la | ✅ | ✅ | ✅ |

O **ADMINISTRADOR** é o único perfil com acesso irrestrito aos relatórios: ele não passa
pela cadeia de permissão. É uma exceção deliberada de autorização e, como tal, exige teste
próprio (ver RN-24).

---

## 4. Escopo do MVP

### 4.1 Coleta

- **F01** — Apuração agendada diária de todos os relatórios cadastrados, por produto.
- **F02** — Registro dos metadados de cada execução: data de referência, data/hora de
  início e fim, status e duração.
- **F03** — Cancelamento, pelo ADMINISTRADOR, de uma execução em andamento.
- **F04** — Solicitação de reprocessamento forçado, pelo ADMINISTRADOR, com motivo
  obrigatório e registro de auditoria.
- **F05** — Expurgo automático dos artefatos após a janela de retenção.

### 4.2 Exportação e consulta

- **F06** — Listagem dos relatórios disponíveis, navegável por data → produto → relatório.
- **F07** — Exportação síncrona de um relatório coletado em PDF, XLSX, DOCX ou CSV.
- **F08** — Download do arquivo exportado.
- **F09** — Consulta, pelo ADMINISTRADOR, do histórico de downloads.

### 4.3 Catálogo

- **F10** — Cadastro, edição e remoção de produtos.
- **F11** — Cadastro, edição e remoção de relatórios.

### 4.4 Identidade e acesso

- **F12** — Entrada e saída da aplicação (*sign in* / *sign out*).
- **F13** — Autocadastro público de RELATOR.
- **F14** — Troca da própria senha e recuperação de senha por e-mail.
- **F15** — Gestão de usuários administrativos (ADMINISTRADOR e GERENTE).
- **F16** — Gestão de roles de relatório e do seu vínculo com relatórios.
- **F17** — Gestão de grupos: criação, vínculo de roles e inclusão/remoção de usuários.

---

## 5. Fora de escopo

Explicitamente **não** faz parte desta versão:

- **MFA** (autenticação multifator).
- **Rotação obrigatória** da senha inicial do ADMINISTRADOR.
- **Verificação de e-mail obrigatória** no autocadastro — o RELATOR entra assim que se
  cadastra, apenas sem acesso a relatório algum até ser vinculado a um grupo.
- **Moderação/aprovação do autocadastro** — não há fila de aprovação; o controle de acesso
  é feito pelo vínculo a grupo.
- **Edição da sigla de um produto** e **edição do código de um relatório** após o cadastro.
- **Agendamento configurável pelo usuário** — a periodicidade da coleta não é editável pela
  aplicação nesta versão.
- **Notificação ativa** (e-mail, push) de conclusão ou falha de execução.
- **Reexportação a partir de artefato expurgado** — passada a janela de retenção, o dado
  daquela data deixa de existir para o sistema.

As exclusões de natureza técnica (Kubernetes, mascaramento e criptografia em repouso, cache
de exportação, deploy em produção/homologação) estão em
[`arquitetura-inicial.md`](./arquitetura-inicial.md#fora-de-escopo) e não são repetidas aqui.

---

## 6. Métrica de sucesso

O sistema existe para que o relatório esteja pronto quando alguém pedir. A métrica
primária mede exatamente isso.

### Primária

> **Taxa de apuração limpa:** percentual das execuções agendadas que terminam em
> `processado com sucesso` — ou seja, sem falha e **dentro** do tempo estimado cadastrado.
>
> **Meta: ≥ 99%, medida em janela móvel de 30 dias.** `PROVISÓRIO — a validar após o
> primeiro mês de operação.`
>
> **Denominador:** execuções agendadas concluídas no período, **excluídas as canceladas** —
> cancelamento é decisão operacional, não falha de apuração (RN-14), e mantê-lo no
> denominador faria a métrica punir o uso correto de F03.
>
> A janela é de 30 dias, e não do ciclo diário, por uma razão aritmética: com o volume
> previsto em RNF-03 (10 execuções por ciclo), uma única falha derruba o dia para 90% e a
> meta de 99% seria inalcançável ou irrelevante. Em 30 dias a série tem ~300 execuções e a
> meta passa a significar algo: no máximo 3 apurações sujas por mês.

### Secundárias

| Métrica | Meta | Por que importa |
|---|---|---|
| Execuções presas em `em processamento` 30 min após o fim do ciclo | **0** | Mede se a detecção de término anômalo funciona. Qualquer valor > 0 é um bug, não uma tendência |
| Reprocessamentos forçados por mês | **≤ 2** `PROVISÓRIO` | É o sintoma. Subiu, a apuração está instável |
| Exportações que terminam em erro | **≤ 1%** `PROVISÓRIO` | Mede a metade do sistema que o usuário sente |

**Instrumentação:** todas devem ser mensuráveis sem consulta manual ao banco, rotuladas por
sigla do produto e código do relatório. A instrumentação é obrigatória — métrica de PRD não
medida de verdade é métrica que não existe (guia, P3).

---

## 7. Conceitos do domínio

Definição única por termo. Esta seção é a semente de `docs/glossario.md`, que ainda não
existe e é exigido pelo P0 do guia.

| Termo | Definição | Não confundir com |
|---|---|---|
| **Produto** | Domínio de negócio com base transacional própria (Poupança, Cliente, Conta Corrente, Consórcio, Empréstimo). Tem **Sigla** e **Nome** | — |
| **Sigla** | Identificador do produto, `^[A-Z]{1,20}$`. Informada no cadastro, **nunca derivada do nome** e **imutável**. Compõe o código do relatório e o caminho de armazenamento | *Nome do produto* |
| **Nome do produto** | Texto livre de exibição, editável a qualquer momento. Não aparece em nenhum identificador | *Sigla* |
| **Relatório** | A **definição** cadastrada: código, nome, descrição, produto e tempo estimado de execução. Existe uma vez e origina muitas Execuções | *Execução*, *Artefato* |
| **Código do relatório** | `SIGLA-NNNN`, regex `^[A-Z]{1,20}-\d{4}$`. Os 4 dígitos são únicos **dentro do produto** — teto de 9.999 relatórios por produto. Imutável | — |
| **Data de referência** | `yyyy-MM-dd`. O dia a que o dado se refere. É **parâmetro de negócio**: particiona o armazenamento e compõe a chave de unicidade | *Data de execução* |
| **Data/hora de execução** | Quando a apuração de fato rodou. Serve para auditoria e para medir duração. Não particiona nada | *Data de referência* |
| **Execução** | Uma apuração do par *Relatório + Data de referência*. Tem status, início, fim e duração | *Exportação* |
| **Artefato** | O resultado gravado de uma Execução bem-sucedida, no repositório | *Arquivo exportado* |
| **Exportação** | Conversão síncrona e sob demanda de um Artefato para um formato de entrega. Nunca é armazenada | *Execução*, *Coleta* |
| **Download** | A entrega do arquivo exportado a um usuário. É registrado, e o registro **sobrevive** ao expurgo do Artefato | *Exportação* |
| **Perfil** | Um de três: ADMINISTRADOR, GERENTE, RELATOR. Conjunto fechado, definido em código | *Role de relatório* |
| **Role de relatório** | Permissão nomeada, criada pelo GERENTE, que agrupa acesso a relatórios. Conjunto **aberto** | *Perfil* |
| **Grupo** | Coleção de usuários que recebe roles de relatório. É o elo entre a permissão e a pessoa | *Role de relatório* |
| **Pendente de vínculo** | RELATOR que se autocadastrou e ainda não pertence a nenhum grupo. Consegue entrar, não alcança nenhum relatório | *Usuário inativo* |
| **Tempo estimado de execução** | Duração esperada da apuração, em segundos, cadastrada por relatório. Governa o alerta e o timeout duro | *Duração real* |

---

## 8. Regras de negócio

### 8.1 Catálogo

- **RN-01** — O Produto tem Sigla e Nome. A Sigla obedece a `^[A-Z]{1,20}$`, é única no
  sistema e imutável após o cadastro. O Nome é livre e editável.
- **RN-02** — O Código do Relatório é `SIGLA-NNNN` (regex `^[A-Z]{1,20}-\d{4}$`), formado
  pela Sigla do produto ao qual pertence. É imutável após o cadastro.
- **RN-03** — Os 4 dígitos do Código do Relatório são únicos dentro de um mesmo Produto.
  Dois produtos diferentes podem ter relatórios com o mesmo sufixo numérico.
- **RN-04** — Todo relatório cadastrado tem **tempo estimado de execução** obrigatório, em
  segundos inteiros e maior que zero.
- **RN-05** — Um Produto só pode ser removido se não tiver relatórios cadastrados.

> Exemplos de código válidos: `POUPANCA-0001`, `CLIENTE-0005`, `CONTACORRENTE-1234`,
> `CONSORCIO-9874`, `EMPRESTIMO-4567`.

### 8.2 Coleta

- **RN-06** — A coleta é agendada e apura todos os relatórios cadastrados.
- **RN-07** — A **Data de referência** é o parâmetro de negócio da execução. Quando não
  informada, assume o dia em que a execução foi disparada, no fuso `America/Sao_Paulo`.
- **RN-08** — O armazenamento é organizado logicamente por
  **data de referência → sigla do produto → código do relatório**. Por depender apenas de
  identificadores imutáveis (RN-01, RN-02), o caminho de um artefato nunca muda.
- **RN-09** — A tabela de metadados de execução é a **fonte da verdade** do status. Nenhuma
  outra fonte pode contradizê-la.
- **RN-10** — Nenhuma execução permanece em `em processamento` indefinidamente. Quando a
  apuração termina de forma anômala e não consegue registrar o próprio encerramento, o
  orquestrador a encerra como `processado com erro`.

### 8.3 Ciclo de vida do status

Cinco status. `em processamento` é o único não-terminal.

| Status | Produziu artefato válido | Usuário pode exportar | Bloqueia nova execução do par |
|---|:---:|:---:|:---:|
| `em processamento` | ❌ | ❌ | ✅ *(enquanto durar)* |
| `processado com sucesso` | ✅ | ✅ | ✅ |
| `processado com alerta` | ✅ | ✅ | ✅ |
| `processado com erro` | ❌ | ❌ | ❌ |
| `cancelado` | ❌ | ❌ | ❌ |

- **RN-11** — `processado com alerta` ocorre **somente** quando a execução concluiu **sem
  nenhuma falha** e sua duração ultrapassou o tempo estimado do relatório. O artefato é
  válido e utilizável; o alerta sinaliza degradação de desempenho, não de conteúdo.
- **RN-12** — Qualquer falha registrada durante a execução resulta em
  `processado com erro`, independentemente da duração. **O erro sempre prevalece sobre o
  alerta.**
- **RN-13** — Ao atingir **o dobro** do tempo estimado, a execução é interrompida por
  timeout duro e encerrada como `processado com erro`.
- **RN-14** — O ADMINISTRADOR pode cancelar uma execução em `em processamento`. Ela é
  encerrada como `cancelado`, e qualquer artefato parcial é descartado. Cancelamento é
  interrupção deliberada e **não** conta como falha nas métricas.
- **RN-15** — Uma execução em status terminal não muda mais de status.
- **RN-42** — Só é possível exportar um relatório cuja execução vigente para aquela data de
  referência esteja em `processado com sucesso` ou `processado com alerta`. Nos demais
  status não existe artefato válido e a exportação é recusada.
- **RN-43** — Enquanto existir execução do par em `em processamento`, nova execução do
  mesmo par é recusada. É a mesma recusa de RN-18: evento de auditoria, não Execução.

### 8.4 Unicidade e reprocessamento

- **RN-16** — Existe no máximo **uma execução vigente** para o par
  *Data de referência + Código do relatório*.
- **RN-17** — Uma nova execução para um par cuja execução vigente esteja em
  `processado com sucesso` ou `processado com alerta` é **recusada**. Os artefatos e os
  metadados originais permanecem intactos.
- **RN-18** — A recusa de RN-17 é registrada como **evento de auditoria** — com solicitante,
  momento e Correlation ID — e **não** cria uma nova Execução. Uma tentativa recusada nunca
  aparece como falha de apuração.
- **RN-19** — Um par cuja execução vigente esteja em `processado com erro` ou `cancelado`
  pode ser executado novamente sem qualquer autorização especial: não há artefato válido a
  preservar.
- **RN-20** — O ADMINISTRADOR pode solicitar o **reprocessamento forçado** de um par já
  concluído com sucesso ou alerta. A solicitação invalida a execução anterior, gera nova
  apuração e **sobrescreve** os artefatos.
- **RN-21** — Toda solicitação de reprocessamento forçado exige **motivo textual
  obrigatório** e é registrada com o identificador do solicitante, o motivo e o
  Correlation ID.

### 8.5 Acesso e autorização

- **RN-22** — A concessão de acesso segue a cadeia
  **Relatório → Role de relatório → Grupo → Usuário**. Todos os elos são **N:N**: um
  relatório pode ter várias roles, uma role pode cobrir vários relatórios, um grupo pode ter
  várias roles e um usuário pode pertencer a vários grupos. O acesso efetivo é a **união**
  de todos os caminhos.
- **RN-23** — Um RELATOR só enxerga e só exporta os relatórios alcançados pela sua cadeia de
  permissão. Relatório fora dela **não aparece na listagem e não é acessível por acesso
  direto**.
- **RN-24** — O ADMINISTRADOR acessa todos os relatórios cadastrados **sem** passar pela
  cadeia de permissão. É a única exceção de autorização do sistema e exige teste automatizado
  dedicado.
- **RN-25** — O GERENTE administra o acesso mas **não** exporta relatórios.
- **RN-26** — O GERENTE não pode criar nem promover outro usuário a GERENTE ou a
  ADMINISTRADOR.
- **RN-27** — O autocadastro público cria **exclusivamente** usuários de perfil RELATOR,
  sempre no estado *pendente de vínculo*.
- **RN-28** — Um RELATOR *pendente de vínculo* consegue entrar na aplicação e recebe uma
  mensagem informando que aguarda a configuração das permissões. Sua listagem de relatórios
  vem vazia.
- **RN-29** — Todo usuário, de qualquer perfil, pode trocar a própria senha e recuperá-la
  por e-mail.

### 8.6 Exportação e formatos

- **RN-30** — A exportação é **síncrona**: devolve o arquivo ou devolve erro na mesma
  requisição. Não possui status persistido — o ciclo de vida de status da seção 8.3 pertence
  exclusivamente à Execução da Coleta.
- **RN-31** — A exportação nunca consulta a base transacional do produto. Lê apenas o
  artefato já apurado.
- **RN-32** — Os formatos de entrega são **PDF, XLSX, DOCX e CSV**.

| Formato | Preserva a paginação | Origem do dado |
|---|:---:|---|
| **PDF** | ✅ | Artefato renderizado |
| **DOCX** | ✅ | Artefato renderizado |
| **XLSX** | ❌ | Artefato renderizado, exportado como planilha contínua |
| **CSV** | não se aplica | Dataset bruto da consulta principal |

- **RN-33** — O artefato é apurado já paginado e posicionado para leitura em página. Traduzir
  esse posicionamento para planilha produz um resultado ilegível; por isso o **XLSX ignora a
  paginação** e é entregue como planilha contínua, sem cabeçalho e rodapé repetidos.
- **RN-34** — O **CSV é o dataset bruto** da consulta principal do relatório — sem
  subrelatórios, sem imagens e sem formatação. É o formato para quem vai reprocessar o dado,
  não para quem vai lê-lo.
- **RN-35** — Todo download é registrado com usuário, relatório, data de referência, formato
  e momento.

### 8.7 Retenção

- **RN-36** — Os artefatos ficam disponíveis por uma **janela de retenção de 7 dias**,
  contada a partir da data de referência. O valor é configurável pela operação.
- **RN-37** — Expirada a janela, os artefatos são expurgados automaticamente e aquela data de
  referência deixa de aparecer na listagem.
- **RN-38** — O **histórico de downloads não é expurgado** junto com os artefatos: sobrevive
  indefinidamente à remoção do dado que registrou.
- **RN-39** — Uma solicitação de exportação de artefato já expurgado é recusada com mensagem
  explícita de indisponibilidade por retenção — nunca com erro genérico.

### 8.8 Erros e diagnóstico

- **RN-40** — Toda mensagem de erro exibida ao usuário contém: **momento do erro**,
  **descrição**, e **Correlation ID**.
- **RN-41** — O Correlation ID exibido ao usuário é o mesmo que permite localizar a
  ocorrência nos registros da operação.

---

## 9. Requisitos funcionais

Cada requisito é uma afirmação verificável por teste automatizado. O detalhamento em
Given/When/Then pertence a `docs/user-stories.md` — artefato P0 exigido pelo guia, ainda
inexistente.

> **Os identificadores são permanentes.** Um `RF-NN` nunca é renumerado nem reaproveitado:
> requisito novo recebe o próximo número livre, ainda que pertença a um grupo anterior;
> requisito descartado tem o ID aposentado. É o que permite que teste, issue e commit
> citem um requisito e a referência continue válida seis meses depois.

### Coleta

| ID | Requisito | Regras |
|---|---|---|
| **RF-01** | A apuração agendada executa todos os relatórios cadastrados e grava um artefato por relatório concluído com sucesso ou alerta | RN-06, RN-08 |
| **RF-02** | Cada execução registra data de referência, início, fim, duração e status | RN-07, RN-09 |
| **RF-03** | Execução que ultrapassa o tempo estimado sem falhas termina em `processado com alerta` | RN-11 |
| **RF-04** | Execução com qualquer falha termina em `processado com erro`, mesmo tendo ultrapassado o tempo estimado | RN-12 |
| **RF-05** | Execução que atinge o dobro do tempo estimado é interrompida e termina em `processado com erro` | RN-13 |
| **RF-06** | Execução cujo processo termina de forma anômala é encerrada como `processado com erro`, sem permanecer em `em processamento` | RN-10 |
| **RF-07** | O ADMINISTRADOR cancela uma execução em andamento; ela termina em `cancelado` e artefatos parciais são descartados | RN-14 |
| **RF-08** | Nova execução de par com execução vigente em sucesso ou alerta é recusada, sem alterar artefatos nem criar execução | RN-16, RN-17, RN-18 |
| **RF-09** | Nova execução de par com execução vigente em erro ou cancelado é aceita normalmente | RN-19 |
| **RF-10** | O ADMINISTRADOR solicita reprocessamento forçado informando motivo; a execução anterior é invalidada e os artefatos sobrescritos | RN-20, RN-21 |
| **RF-11** | Solicitação de reprocessamento forçado sem motivo é rejeitada | RN-21 |
| **RF-12** | Usuário de perfil diferente de ADMINISTRADOR não consegue cancelar execução nem solicitar reprocessamento forçado | RN-14, RN-20 |

### Exportação e consulta

| ID | Requisito | Regras |
|---|---|---|
| **RF-13** | A listagem apresenta os relatórios disponíveis navegáveis por data → produto → relatório, exibindo a data em `dd/MM/yyyy` | RN-08 |
| **RF-14** | A listagem de um RELATOR contém exclusivamente os relatórios alcançados pela sua cadeia de permissão | RN-22, RN-23 |
| **RF-15** | Tentativa de acesso direto a relatório fora da permissão do usuário é negada | RN-23 |
| **RF-16** | A listagem de um RELATOR pendente de vínculo vem vazia, acompanhada da mensagem de aguardo | RN-28 |
| **RF-17** | O ADMINISTRADOR enxerga e exporta todos os relatórios cadastrados | RN-24 |
| **RF-18** | O GERENTE não consegue exportar relatório algum | RN-25 |
| **RF-19** | A exportação devolve o arquivo no formato solicitado dentro da mesma requisição, sem criar registro de status | RN-30 |
| **RF-20** | Só é possível exportar relatório cuja execução vigente esteja em sucesso ou alerta | RN-42 |
| **RF-21** | A exportação em XLSX é entregue como planilha contínua, sem repetição de cabeçalho e rodapé por página | RN-33 |
| **RF-22** | A exportação em CSV entrega o dataset bruto da consulta principal | RN-34 |
| **RF-23** | Todo download é registrado e consultável pelo ADMINISTRADOR | RN-35, F09 |
| **RF-24** | Solicitação de artefato já expurgado é recusada com mensagem de indisponibilidade por retenção | RN-39 |

### Catálogo

| ID | Requisito | Regras |
|---|---|---|
| **RF-25** | O cadastro de produto exige Sigla válida e única, e Nome; a Sigla não é editável depois | RN-01 |
| **RF-26** | O cadastro de relatório gera código no formato `SIGLA-NNNN`, único dentro do produto | RN-02, RN-03 |
| **RF-27** | O cadastro de relatório exige tempo estimado de execução em segundos, maior que zero | RN-04 |
| **RF-28** | Remoção de produto com relatórios cadastrados é rejeitada | RN-05 |
| **RF-41** | Nome e descrição de produto e de relatório são editáveis; sigla e código não | RN-01, RN-02 |
| **RF-42** | Remoção de relatório é rejeitada enquanto existir execução dele dentro da janela de retenção | Q2 |
| **RF-43** | Remoção de role de relatório ou de grupo revoga o acesso concedido por eles, sem afetar outros caminhos da cadeia | RN-22 |

### Identidade e acesso

| ID | Requisito | Regras |
|---|---|---|
| **RF-29** | O autocadastro público cria usuário RELATOR pendente de vínculo | RN-27 |
| **RF-30** | O autocadastro não permite escolher perfil nem criar GERENTE/ADMINISTRADOR | RN-27 |
| **RF-31** | O GERENTE cria roles de relatório e as vincula a relatórios e a grupos | RN-22 |
| **RF-32** | O GERENTE inclui e remove usuários RELATOR em grupos | RN-22 |
| **RF-33** | Usuário em múltiplos grupos acessa a união dos relatórios de todos eles | RN-22 |
| **RF-34** | O GERENTE não consegue criar nem promover usuário a GERENTE ou ADMINISTRADOR | RN-26 |
| **RF-35** | ADMINISTRADOR e GERENTE conseguem remover um usuário RELATOR | matriz §3.2 |
| **RF-36** | Removido o vínculo de um usuário, seu acesso aos relatórios correspondentes cessa imediatamente | RN-22 |
| **RF-37** | Qualquer usuário troca a própria senha e recupera senha esquecida por e-mail | RN-29 |

### Erros

| ID | Requisito | Regras |
|---|---|---|
| **RF-38** | Toda mensagem de erro exibe momento, descrição e Correlation ID | RN-40 |
| **RF-39** | A tela de erro oferece a cópia do erro em formato estruturado, para anexar em chamado | RN-40 |
| **RF-40** | O Correlation ID exibido localiza a ocorrência nos registros da operação | RN-41 |

---

## 10. Requisitos não-funcionais

> Os números abaixo são **pontos de partida**, não medições. Estão marcados `PROVISÓRIO`
> justamente para serem contestados: um número errado e visível provoca a discussão; a
> ausência de número não provoca nada. A primeira versão executa somente em ambiente local
> — não há metas de disponibilidade nem de escala horizontal.

| ID | Requisito | Valor |
|---|---|---|
| **RNF-01** | Relatórios cadastrados no MVP | 10 (2 por produto, 5 produtos) `PROVISÓRIO` |
| **RNF-02** | Teto de relatórios por produto | 9.999 — decorre de RN-03, não é provisório |
| **RNF-03** | Execuções por ciclo diário | 10 `PROVISÓRIO` |
| **RNF-04** | Janela do ciclo de coleta | Concluir em até 60 min `PROVISÓRIO` |
| **RNF-05** | Tamanho máximo de artefato | 50 MB `PROVISÓRIO` |
| **RNF-06** | Volume máximo do dataset de um relatório | 500.000 linhas `PROVISÓRIO` |
| **RNF-07** | Latência de exportação, p95 — PDF | ≤ 5 s `PROVISÓRIO` |
| **RNF-08** | Latência de exportação, p95 — XLSX e DOCX | ≤ 15 s `PROVISÓRIO` |
| **RNF-09** | Latência de exportação, p95 — CSV | ≤ 2 s `PROVISÓRIO` |
| **RNF-10** | Exportações simultâneas suportadas | 10 `PROVISÓRIO` |
| **RNF-11** | Usuários simultâneos | 25 `PROVISÓRIO` |
| **RNF-12** | Janela de retenção dos artefatos | 7 dias, configurável — RN-36 |
| **RNF-13** | Retenção do histórico de downloads | Indefinida — RN-38 |
| **RNF-14** | Fuso horário de todo o sistema | `America/Sao_Paulo` |
| **RNF-15** | Idioma da interface e das mensagens | pt-BR |

---

## 11. Decisões assumidas nesta revisão

Cada linha resolve uma ambiguidade ou contradição da versão anterior deste PRD. Estão
listadas para poderem ser contestadas individualmente.

| # | O que estava ambíguo | Decisão | Onde |
|---|---|---|---|
| D01 | O PRD misturava produto e arquitetura | O PRD trata só do eixo de produto; o técnico foi remetido a `arquitetura-inicial.md` | §1, §13 |
| D02 | "O alerta prevalece sobre o erro" mascarava falhas entre 1× e 2× o tempo estimado | **O erro sempre prevalece.** Alerta só sem falha | RN-11, RN-12 |
| D03 | "A data é o dia em que o job rodou" conflitava com "data de referência" | **Dois conceitos distintos.** A data de referência é parâmetro de negócio e admite apuração retroativa | RN-07, §7 |
| D04 | ADMINISTRADOR podia gerar relatórios, mas não havia ramo para ele na cadeia de permissão | **Acesso irrestrito, sem passar pela cadeia**, com teste dedicado | RN-24 |
| D05 | "O par é único" contradizia "a execução recusada é registrada como erro" | A unicidade vale para a **execução vigente**; a recusa é **evento de auditoria**, não Execução | RN-16, RN-18 |
| D06 | O ADMINISTRADOR podia cancelar, mas `cancelado` não existia entre os status | **Quinto status terminal `cancelado`**, que não conta como falha | RN-14, §8.3 |
| D07 | "Nome do produto" era ao mesmo tempo rótulo, parte do código e parte do caminho | **Sigla imutável** separada do **Nome** editável | RN-01, §7 |
| D08 | A cadeia relatório→role→grupo→usuário não declarava cardinalidades | **N:N em todos os elos**, acesso pela união dos caminhos | RN-22 |
| D09 | O ciclo de status parecia valer também para a exportação síncrona | Vale **só para a Execução da Coleta** | RN-30 |
| D10 | O reprocessamento forçado era parâmetro de orquestração, mas exigia identificar o solicitante | Vira **funcionalidade da aplicação**, autenticada e auditada | F04, RN-20 |
| D11 | A retenção de 7 dias era só configuração de infraestrutura | Vira **regra de negócio**, com o comportamento visível ao usuário | RN-36 a RN-39 |
| D12 | Não se dizia se erro, alerta ou cancelado bloqueavam nova execução | **Sucesso e alerta bloqueiam** (há artefato); **erro e cancelado liberam** | RN-17, RN-19 |
| D13 | Não havia métrica de sucesso | **Taxa de apuração limpa** como primária, mais três secundárias | §6 |
| D14 | O ADMINISTRADOR não podia remover RELATOR, embora removesse GERENTE | **ADMINISTRADOR também remove RELATOR** | §3.2, RF-35 |
| D15 | Não se dizia se a listagem era filtrada por permissão | **Filtrada**, inclusive contra acesso direto | RN-23 |
| D16 | *Sign up* não dizia qual perfil, nem se exigia verificação de e-mail | **Só RELATOR**, sem verificação obrigatória e sem moderação; **recuperação de senha entra no MVP** | RN-27, F14 |
| D17 | O tempo estimado governava alerta e timeout, mas não constava do cadastro | **Obrigatório**, em segundos, maior que zero | RN-04 |
| D18 | O texto dizia que exportar CSV pelo mecanismo de renderização "sai feio", mas o CSV não passa por ele | **PDF e DOCX paginam; XLSX ignora a paginação; CSV é dataset bruto** | RN-32 a RN-34 |
| D19 | Nenhum requisito não-funcional era quantificado | **Metas provisórias numéricas**, explicitamente marcadas | §10 |

### Regras acrescentadas sem discussão prévia

Estas não constavam da versão anterior e não foram objeto de decisão explícita. São
derivações defensáveis, marcadas aqui justamente por não terem sido confirmadas:

- **RN-05** (produto só é removido sem relatórios) e **RF-42** (relatório não é removido
  com execução na janela de retenção) — evitam órfãos no armazenamento e no histórico.
- **RN-15** (status terminal não muda mais), **RN-42** (só exporta de sucesso ou alerta) e
  **RN-43** (`em processamento` bloqueia nova execução) — tornam o ciclo de vida
  verificável; a versão anterior deixava os três casos implícitos.
- **RN-31** (a exportação nunca lê a base transacional) — é o propósito do sistema, mas
  não estava escrito em lugar nenhum como proibição.
- **RN-35** (todo download é registrado) — estava implícito em "visualização do histórico
  de downloads" do perfil ADMINISTRADOR, sem nunca ter sido declarado como requisito.

### Regras da versão anterior removidas deliberadamente

- A regra sobre tempo estimado aparecia **duas vezes**, sendo uma subconjunto da outra.
  Restou uma formulação única (RN-11 a RN-13).
- A explicação do comportamento interno do mecanismo de exportação de planilhas saiu: é
  justificativa técnica de uma decisão de produto que agora está declarada em RN-33.
- "Estrutura com os dados não estruturados" foi descartada por ser autocontraditória e não
  descrever requisito algum. A hierarquia lógica está em RN-08; o formato dos artefatos é
  assunto de arquitetura.

---

## 12. Questões em aberto

| # | Questão | Impacto | Precisa ser resolvida antes de |
|---|---|---|---|
| **Q1** | Qual a periodicidade e o horário exatos da coleta agendada? | Define a janela operacional e a meta de RNF-04 | Implementar o agendamento |
| **Q2** | Quando um relatório é removido do catálogo, o que acontece com os artefatos, as execuções e o histórico de downloads já registrados? RF-42 propõe bloquear a remoção enquanto houver execução dentro da janela de retenção — falta confirmar | Integridade do histórico e do registro de downloads | Implementar F11 (remoção de relatório) |
| **Q3** | Alterar o tempo estimado de um relatório reclassifica execuções passadas, ou o valor vigente à época fica congelado na execução? | Comparabilidade histórica da métrica primária | Implementar RF-41 |
| **Q4** | O reprocessamento forçado tem limite de retroatividade — pode alcançar uma data já fora da janela de retenção? | Interação entre RN-20 e RN-37 | Implementar F04 |
| **Q5** | Os números provisórios de §10 valem? Qual o volume real esperado por relatório? | Todas as metas de latência e capacidade | Fechar os critérios de aceite não-funcionais |
| **Q6** | A meta de 99% da métrica primária é adequada para o cenário? | A métrica de sucesso do produto | Instrumentar P3 |
| **Q7** | Existe algum relatório que deva ser visível a todos os RELATORES sem vínculo específico? | Pode exigir o conceito de grupo padrão | Implementar RN-22 |
| **Q8** | A janela de retenção conta a partir da **data de referência** (RN-36) ou da data de gravação do artefato? Com apuração retroativa (RN-07) as duas divergem: um artefato de data antiga nasceria já expirado | Define se backfill é utilizável | Implementar F05 (expurgo) |
| **Q9** | RNF-04 fixa 60 min para o ciclo, mas RN-13 permite que cada execução chegue ao dobro do tempo estimado. Nada garante que a soma caiba na janela — as execuções são paralelas? Há teto de tempo estimado por relatório? | Viabilidade da janela operacional | Fechar RNF-04 |

---

## 13. Documentos relacionados

| Documento | Papel | Estado |
|---|---|---|
| [`arquitetura-inicial.md`](./arquitetura-inicial.md) | Eixo de engenharia: stack, módulos, regras arquiteturais, trade-offs | Existe |
| [`guias/guia-app-web.md`](./guias/guia-app-web.md) | Método: define os artefatos exigidos em cada fase | Existe |
| `glossario.md` | Linguagem ubíqua completa. A seção 7 deste PRD é a semente | **Não existe** — exigido por P0 |
| `user-stories.md` | Histórias com critério de aceite em Given/When/Then, derivadas dos RF da seção 9 | **Não existe** — exigido por P0 |
| `design/fluxos.md` | Os fluxos principais com estados de erro | **Não existe** — P1 |

> **Nota de migração.** Ao reescrever este PRD, conteúdo de natureza técnica foi retirado e
> deve ser incorporado a `arquitetura-inicial.md`, que ainda não o contém integralmente: o
> formato e as extensões dos artefatos gravados; o encadeamento orquestrador → contêiner de
> processamento → base transacional → repositório; o nome do parâmetro que aciona o
> reprocessamento forçado; e o mecanismo pelo qual o orquestrador encerra execuções que
> terminaram de forma anômala (RN-10).
