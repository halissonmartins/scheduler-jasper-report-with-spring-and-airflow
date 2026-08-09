# 05 — Catálogo seed: os dez relatórios de exemplo e seus modelos de dados

**O que construir:** a definição, não o código. Ao fim deste ticket existe um documento que diz,
para cada um dos cinco produtos, **quais são os seus dois relatórios** — código, nome, descrição,
tempo estimado inicial e consulta principal — e qual é o **modelo de dados** do schema transacional
de onde cada um lê. Nenhum JRXML é escrito aqui.

Vem antes de tudo porque hoje é uma lacuna com consumidores já marcados como prontos: a arquitetura
§14 e a especificação §6 listam *"definição dos relatórios de exemplo (RA-08) e seus respectivos
modelos de dados"* como pendência aberta, enquanto o ticket 06 manda publicar *"produto e os seus
relatórios, com sigla, código, nome, descrição e tempo estimado"* e o ticket 10 manda o módulo trazer
*"o JRXML e a consulta"*. Sem esta definição, a primeira sessão inventa os dez relatórios — e a
invenção entra como fato consumado em toda a cadeia a jusante, a começar pelo molde da costura S2.

**Bloqueado por:** nada — pode começar imediatamente.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] **RNF-01, RA-08** — os **dez** relatórios definidos: dois por produto, para os cinco produtos
      de RA-04.
- [ ] **RN-02, RN-03, RN-04** — cada um com código `SIGLA-NNNN`, os quatro dígitos únicos dentro do
      produto, nome, descrição e **tempo estimado inicial** em segundos inteiros maior que zero.
- [ ] **RN-48, RNF-19** — a soma dos tempos estimados de cada produto cabe no teto, verificável no
      papel antes de existir código. Um catálogo seed que já nasce estourando o teto faz o módulo não
      subir no ticket 06, e o achado apareceria como bug de implementação em vez de erro de
      definição.
- [ ] **Modelo de dados do schema transacional de cada produto** — as tabelas de onde a consulta
      principal lê. Cinco schemas independentes, cada um lido **exclusivamente** pelo seu próprio
      módulo (RA-10).
- [ ] **RA-17, RN-34** — a **consulta principal** de cada relatório, declarada: é ela que vira o
      dataset bruto do `.csv.gz` e a base do JRXML.
- [ ] Volume semeável **abaixo do teto de RNF-06** no caminho feliz, e um caminho semeável **acima**
      dele para o cenário de recusa do ticket 11 (RF-49). Sem um dataset grande de propósito, aquele
      critério não tem como ser exercido.
- [ ] **Distribuição das características de risco**, com o mapa escrito de qual relatório cobre qual:
      RA-08 exige imagens e fontes diferentes **dentro de cada par**, e as armadilhas de serialização
      da arquitetura §12 — `serialVersionUID`, imagens embutidas, fontes **não** embutidas e
      **renderers serializados** — ficam cobertas por ao menos um relatório cada. A dos renderers não
      é coberta por nenhuma regra existente e é a que ninguém escolheria espontaneamente.
- [ ] Um par com **um relatório notoriamente mais lento que o outro**: o ticket 11 precisa de "um
      lento e um são" para provar que abortar um não derruba o vizinho (RF-05).
- [ ] **Nenhum JRXML é escrito neste ticket.** A convenção de autoria é do ticket 17, e escrever
      modelo antes dela é exatamente o apodrecimento que o ADR-0006 prevê.
- [ ] A definição vive em documento versionado em `docs/`, e a pendência sai de
      `arquitetura-inicial.md` §14 e de `especificacao.md` §6 — pendência resolvida que continua
      listada como aberta é ruído que custa uma leitura inteira.
- [ ] Os códigos do PRD §8.1 permanecem **ilustração do regex** e não são promovidos a catálogo. São
      cinco, um por produto, com dígitos deliberadamente espalhados; quem chega com pressa os toma
      por definição.
