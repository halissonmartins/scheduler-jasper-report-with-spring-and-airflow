# Geração e download síncronos, com limites globais e sem bulkhead

A Geração é síncrona: a requisição devolve o arquivo no próprio response, transmitido em streaming. Não há job assíncrono, nem artefato persistido, nem endpoint de polling. A proteção é composta apenas por limites globais de linhas por formato e por timeouts elevados — sem semáforo de concorrência. O frontend baixa via `fetch()` + blob com o header `Authorization`.

Os quatro Status de Processamento, portanto, pertencem à Coleta (ADR-0007 e CONTEXT.md); a Geração grava apenas sua própria linha de auditoria com início, fim, duração e desfecho.

## Considered Options

- **Job assíncrono (202 + polling + artefato)** — recomendado e recusado. Sobreviveria a timeouts de gateway, permitiria retomada e daria feedback de progresso.
- **Semáforo de concorrência (bulkhead) com 429** — recomendado e recusado.
- **Token de download de uso único na URL** — recomendado e recusado; permitiria ao navegador baixar nativamente, em streaming para o disco, sem teto de memória.

## Consequências (riscos aceitos)

- Uma Geração grande pode causar OOM no container da API e derrubar as requisições em voo dos outros usuários. Os exportadores XLSX/DOCX do Jasper montam o documento em memória (não são streaming).
- O timeout de leitura do ingress/LB precisa ser configurado acima do pior caso de Geração. Se estourar, o usuário recebe um arquivo truncado e corrompido — não uma página de erro — porque os primeiros bytes já foram enviados.
- Uma conexão interrompida desperdiça a Geração inteira; não há artefato para reaproveitar.
- **Os limites de linhas passam a ser ditados pela memória do navegador**, não pela vazão do servidor: o blob retém o arquivo inteiro na aba. Na prática os limites ficam na casa das centenas de milhares de linhas para todos os formatos, inclusive CSV. **Extrações completas dos maiores Relatórios não são entregáveis.** Gzip não resolve (o navegador descomprime antes do blob). Saída futura possível: streaming via `showSaveFilePicker()`, só em navegadores Chromium.
- Os limites são **constantes versionadas no código**, uma por Formato de Exportação, e mudam por release — inclusive para baixo, durante um incidente. Valores iniciais, deliberadamente conservadores: CSV 500.000, XLSX 100.000, PDF 25.000, DOCX 25.000 linhas. Antes de gerar, a API faz uma contagem prévia pelo índice composto e recusa de imediato o que excede o limite.
- O benchmark k6 refina esses valores: executar a Geração com contagens crescentes medindo tempo de parede, heap da API e tamanho da resposta, e fixar cada limite em ~60% do orçamento de timeout e ~50% do heap seguro, validando contra o teto de blob dos navegadores-alvo. Enquanto o benchmark não existir, valem os valores iniciais.
