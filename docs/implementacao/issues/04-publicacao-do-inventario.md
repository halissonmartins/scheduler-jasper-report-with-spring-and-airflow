# 04 — Publicação do inventário (`--publicar-inventario`)

**O que construir:** o passo de bootstrap que torna o cadastro de Relatórios possível. A mesma
imagem do processador sobe num segundo modo, varre os Relatórios que ela carrega, publica o
inventário e sai. É o que impede Relatório fantasma — um cadastro sem código por trás, que subiria
um container todo dia condenado a falhar, virando `ERRO` legítimo e indistinguível de falha real.

**Bloqueado por:** 01, 02.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] A imagem aceita o modo, publica o inventário e sai — idempotente, seguro de rerodar.
- [ ] A publicação é **declarativa**: o inventário passa a refletir exatamente os Relatórios
      presentes na imagem, não um acréscimo ao que já estava lá.
- [ ] `CO-INVENTARIO-DECLARATIVO` — publicar a partir de uma imagem sem o Relatório de um cadastro
      existente **retira-o do inventário**, deixa o cadastro sinalizado como "cadastrado, não
      publicado", e **não** apaga o cadastro nem falha o deploy.
- [ ] O estado inverso é visível: "publicado, não cadastrado".
- [ ] `CO-BOOTSTRAP-ORDEM` — a sequência migrações do controle → migrações transacionais →
      publicação do inventário → API é exercitada. Ela quebra em silêncio: sem inventário nada é
      cadastrável e o sistema simplesmente não faz nada.
- [ ] Só o bootstrap escreve o inventário. Nenhuma credencial de runtime ganha escrita nessa tabela.
