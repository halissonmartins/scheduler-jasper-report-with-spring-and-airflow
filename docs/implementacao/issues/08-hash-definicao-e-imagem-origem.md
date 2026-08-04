# 08 — `hash_definicao`, `imagem_origem` e divergência de inventário

**O que construir:** duas Execuções do mesmo Relatório em dias diferentes podem ter saído de
definições diferentes, e hoje nada registra isso. A promessa é **registrar, não avisar**: cada
Execução grava qual definição a produziu, e quem investiga chega ao commit. A tela do relator não
muda.

**Bloqueado por:** 04, 05.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Cada Execução grava `hash_definicao` (SHA-256 de JRXML + consulta + rótulos) e `imagem_origem`
      como **colunas**, ao lado da versão do JasperReports.
- [ ] **Quem calcula é o container**, dos próprios Relatórios que ele carrega — não o inventário.
      Ler o hash publicado gravaria o que ele *alega*, e uma imagem subida sem republicar faria o
      histórico mentir em silêncio.
- [ ] `CO-HASH-ESTAVEL` — o mesmo Relatório, em duas JVMs distintas, produz o mesmo hash. A entrada
      é canônica: ordem fixa dos rótulos, encoding fixo, SQL literal. Hash que muda por reordenação
      de coleção vira ruído e mata o mecanismo em uma semana.
- [ ] `CO-INVENTARIO-DIVERGENTE-NAO-FALHA` — hash divergente do inventário termina em `SUCESSO`
      **com a métrica incrementada**. O assert é na métrica: verificar só que o job passou não
      distingue isso de a comparação nem existir.
- [ ] O mapeamento fica **fora** do hash — é método, não dado. A documentação da SPI diz isso, e a
      cobertura vem de `imagem_origem`.
- [ ] Nada reprocessa sozinho depois de um deploy. Reprocesso automático faria de um deploy um
      destruidor de histórico, porque reprocessar apaga a Execução anterior.
