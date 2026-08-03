# 31 — Swagger descartável: o contrato REST completo

Type: prototype
Status: resolved
Blocked by: 01, 04, 15, 25

## Question

Como é o contrato REST inteiro, escrito como OpenAPI antes de existir código?

Fase inicial do documento: "Swagger descartável onde depois será substituído pelo SpringDOC OpenAPI". O artefato é descartável, mas as decisões que ele força não são — escrever o contrato é o que revela ambiguidade.

Produzir um arquivo OpenAPI cobrindo:

- **Autenticação**: como o token entra, e o esquema de segurança declarado.
- **Listagem de relatórios disponíveis**: filtro por data, produto e código, filtrado pelo que o usuário pode ver (ticket 15). É essa a API que alimenta o drop-down do ticket 32.
- **Geração e download**: em conformidade com a decisão do ticket 25 (síncrono, `202` + polling, ou híbrido), por formato (PDF, CSV, XLSX, DOCX).
- **Cadastro de produtos e de relatórios** (ADMINISTRADOR), incluindo o tempo estimado de execução.
- **Gestão de roles de relatório, grupos e vínculos** (GERENTE) — a cadeia relatório → role → grupo → usuário.
- **Gestão de usuários** e o fluxo de cadastro público (ticket 16).
- **Histórico de downloads** (ADMINISTRADOR).
- **Schema de erro** conforme o ticket 26, referenciado por toda resposta de erro.

Ao final, **solicitar revisão e aguardar aprovação** antes de encerrar a fase (regra do documento). Gravar o artefato em `docs/mapa/prototipos/openapi-descartavel.yaml` e linkar daqui.

## Notas do ticket 23 (contrato do CSV)

- **A descrição do endpoint de exportação é o único lugar onde a divergência PDF × CSV é explicada.**
  O ticket 23 decidiu não avisar na UI, então o texto no OpenAPI deixa de ser documentação de apoio e
  passa a ser o registro da regra. Precisa estar no protótipo desde já, não acrescentado depois.
- **O CSV tem caminho diferente dos outros três formatos.** Ele não desserializa nada — já está
  gravado — então pode ser servido direto, inclusive com `Content-Encoding: gzip`. Se o ticket 25
  optar por fluxo assíncrono para PDF/XLSX/DOCX, o contrato precisa refletir que **o CSV não segue o
  mesmo protocolo**, e isso é decisão de desenho de API, não detalhe de implementação.
- **Dois verbos de disparo manual de Coleta** (ticket 20): `refazer` e `reprocessar`, com regras de
  validade diferentes decididas pelo servidor. O contrato precisa expressar que o cliente não escolhe
  livremente — ele pergunta qual é válido, ou tenta e recebe recusa tipada.

## Notas do ticket 25 (geração sob demanda)

- **A exportação é síncrona** — `200` com os bytes, não `202` com protocolo de polling. Isso simplifica
  bastante o contrato: um verbo, sem recurso de "exportação em andamento", sem TTL, sem URL de
  recuperação. O protótipo não precisa modelar um segundo ciclo de vida.
- **Três respostas de erro precisam estar no contrato desde já**, e duas delas se confundem
  facilmente: `409` para Artefato acima do teto (**permanente** — repetir não adianta) e `503` com
  `Retry-After` para semáforo cheio (**transitório** — repetir é o certo).
- **O CSV tem caminho próprio** e responde com `Content-Encoding: gzip`. Vale explicitar no contrato,
  porque é a diferença entre o cliente receber bytes comprimidos e receber o arquivo pronto.
- **O `Content-Disposition`** de cada formato — nome de arquivo que o usuário vê ao salvar — é decisão
  de contrato e aparece no protótipo antes de existir backend.

## Notas do ticket 26 (formato de erro)

- **O schema de erro está fechado e é RFC 9457**, com `application/problem+json` e as extensões
  `codigo`, `momento` e `correlationId`. O `type` é URN não dereferenciável (`urn:relatorios:erro:…`),
  então o protótipo não precisa hospedar catálogo algum.
- **O catálogo tem dezesseis códigos** já nomeados no ticket 26, com o HTTP de cada um. O protótipo
  deve referenciar o schema em toda resposta de erro e trazer exemplos de pelo menos os dois que se
  confundem — `ARTEFATO_ACIMA_DO_LIMITE` (409, permanente) e `EXPORTACAO_INDISPONIVEL` (503 +
  `Retry-After`, transitório).
- **O botão de copiar JSON não entra no contrato**, e a razão é boa: o corpo da resposta **já é** o
  JSON, então o botão copia a resposta verbatim. Isso é nota para o protótipo do frontend, não para o
  OpenAPI.
- **`SEM_PERMISSAO_PARA_RELATORIO` é deliberadamente genérico** — quatro situações distintas produzem
  a mesma saída. A descrição no OpenAPI precisa dizer isso, senão parece imprecisão a ser corrigida.

## Answer

Artefato: [`../prototipos/openapi-descartavel.yaml`](../prototipos/openapi-descartavel.yaml) — 16
caminhos, 11 schemas, 8 respostas reutilizáveis, OpenAPI 3.1. **Fase encerrada com aprovação**,
conforme a regra do documento.

O arquivo é descartável; as decisões abaixo não são.

### Decisões de forma tomadas antes de escrever

**Duas formas de endereçar uma Execução, de propósito.** A chave natural
(`/relatorios/{codigo}/execucoes/{data}`) endereça a Execução **disponível** daquele par — legível,
derivável do drop-down sem consulta prévia, e é o que o relator usa. O identificador opaco
(`/execucoes/{id}`) endereça **uma linha específica**, inclusive tentativas que falharam.

Não é duplicação: são perguntas diferentes. E a razão de precisar das duas é que **a chave natural
deixou de ser única** — o índice único parcial do ticket 20 exclui `ERRO` e `SEM_DADOS`, então um par
acumula linhas e só uma fica em `SUCESSO`/`ALERTA`.

**Formato como parâmetro de consulta** (`?formato=`), não sufixo de caminho. Uma operação no OpenAPI,
com o catálogo de erro anexado **uma vez** — sufixo produziria quatro operações com as mesmas quatro
respostas repetidas, que divergem na primeira edição. A diferença de comportamento do CSV vira nota
documentada por valor do enum.

**Uma listagem filtrada**, não três endpoints em cascata. Com retenção de 7 dias e dez Relatórios
diários, o conjunto inteiro de Execuções disponíveis é de ~70 linhas — cabe numa resposta, e o
drop-down troca de nível sem ir à rede. Espelhar a navegação em três endpoints custaria três idas ao
servidor sobre um dado que cabia numa.

### O que escrever o contrato forçou para fora

**Um recurso que a lista do ticket não previa: `/inventario`.** Ele apareceu sozinho — a validação do
cadastro precisa consultá-lo, e os dois estados de descompasso (*publicado, não cadastrado* e
*cadastrado, não publicado*) precisam ser visíveis em algum lugar, senão o operador não tem como
diagnosticar por que um Relatório não roda.

**Existem duas assincronias diferentes, e a discussão tratou de uma só.** A exportação é síncrona
(`200` com os bytes, ticket 25), mas `refazer` e `reprocessar` respondem `202` — porque a **Coleta**
é assíncrona por natureza. Escrever as duas lado a lado deixou a distinção óbvia; ela não estava
escrita em lugar nenhum.

**Lista vazia não é erro, e precisou estar dito.** `/execucoes-disponiveis` devolvendo `[]` é o
**estado** que leva à página dedicada do ticket 16 — não um `403`. Sem a nota, seria modelado como
erro na primeira implementação.

**Um `500` com código de negócio**: `VINCULACAO_INCOMPLETA` em `/grupos/{id}/membros`. Incomum
documentar 500 assim, mas é o que o ticket 16 exigiu — a operação composta (entrar no Grupo, sair do
`PENDENTES`) pode falhar pela metade, e o GERENTE precisa saber disso em vez de receber sucesso
silencioso.

**Três campos derivados na listagem** — `temDados`, `expirado` e `expuragoPrevisto`. O cliente precisa
dos três para distinguir *disponível*, *sem dados* e *expirado*, que são estados diferentes com
aparências parecidas.

### O que ficou deliberadamente de fora

**Login, logout e troca de senha não têm endpoint.** O SPA fala direto com o Keycloak — RP-initiated
logout e Account Console, conforme o ticket 17. Colocá-los aqui sugeriria que a API os intermedia, e
ela não intermedia, de propósito.

### O que a substituição pelo SpringDOC precisa preservar

- A **descrição da exportação** é o único lugar onde a divergência PDF × CSV aparece para quem integra
  (ticket 23, risco aceito). Ela não é verbosidade a limpar.
- A distinção entre `409` (permanente) e `503` com `Retry-After` (transitório), com exemplos —
  confundi-las na UI produz usuário insistindo no que nunca passa e desistindo do que passaria.
- A nota de que `SEM_PERMISSAO_PARA_RELATORIO` é **genérico por decisão**, cobrindo quatro situações.
- A **exceção conhecida** no schema de erro: cabeçalho acima do limite do Tomcat é rejeitado antes de
  qualquer filtro, sem corpo padronizado e sem Correlation ID.
