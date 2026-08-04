# 16 — Exportação CSV

**O que construir:** o primeiro download que funciona, pelo caminho mais barato do sistema. O CSV é
o único formato que **não desserializa nada** — já está gravado, e a API busca, confere a
integridade e transmite. Prova o fluxo inteiro de exportação sem carregar o risco de heap dos outros
três.

**Bloqueado por:** 05, 15.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] O fluxo é autorizar (pela claim, sem I/O) → buscar o Artefato → conferir o SHA-256 →
      transmitir. A integridade é conferida **mesmo sem desserialização**.
- [ ] O CSV é servido comprimido, sem os bytes passarem pelo heap da API.
- [ ] A API busca por **chave conhecida**, nunca por listagem — a credencial dela não tem permissão
      de enumerar o acervo, de propósito.
- [ ] Cada entrega grava uma linha de Download como **fotografia denormalizada**, legível sozinha
      para sempre: quem, quando, qual Relatório e Produto na época, data, formato.
- [ ] `CO-BYPASS-ADMINISTRADOR` (marcação) — quando o acesso veio do Perfil e não de Role, a linha
      sai marcada. Sem isso, "o que os ADMINISTRADORes andaram baixando" exige inferência.
- [ ] A exportação é **síncrona**: `200` com os bytes. Não há recurso de "exportação em andamento",
      TTL nem URL de recuperação.
- [ ] A descrição do endpoint carrega a regra de negócio — PDF, XLSX e DOCX são a **visão
      formatada**; o CSV é o **dataset** da consulta principal, e totais do relatório podem não ser
      reproduzíveis a partir dele. É o único lugar onde isso aparece para quem integra, e não é
      verbosidade a limpar.
