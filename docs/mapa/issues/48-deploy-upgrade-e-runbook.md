# 48 — Deploy, upgrade e runbook de incidente

Type: grilling
Status: resolved
Blocked by: —

## Question

Como o sistema vai para produção, como sobe de versão, e o que se faz quando quebra?

Graduou da névoa carregando quatro procedimentos que ganharam risco próprio ao longo do mapa. A névoa
os acumulou; agora eles são específicos o bastante para virar decisão.

Decidir:

- **O procedimento de deploy.** O ticket 30 aceitou que o **CI para no teste**, então a VM constrói as
  imagens: ela precisa de toolchain de build, e o deploy tem de **fixar SHA ou tag, nunca `main`
  HEAD** — sem registry, o commit é o único elo entre o que foi testado e o que roda.
- **A ordem de subida.** O ticket 04 registrou uma sequência com `--publicar-inventario` por módulo
  (passo idempotente de bootstrap). O ticket 37 tornou o inventário obsoleto **detectável mas não
  fatal**. Decidir onde cada passo entra e o que é pré-requisito de quê.
- **O passo manual da árvore de Grupos** (ticket 38): criar a raiz, o `PENDENTES` e a marcação de
  Default Group, lembrando que o `--import-realm` é **pulado** em realm existente. A API confere por
  leitura no boot e reclama pelo health group `dependencias`.
- **O upgrade do Keycloak** (ticket 17): acumulou-se configuração viva que o import de realm não
  reproduz — allowlist do Traefik que falha fechada por decisão, permissões de FGAP, Default Group,
  Account Console enxugado. Decidir o que é reaplicado, em que ordem, e como se confere.
- **A chave de licença do AIStor** (ticket 35 / ADR 0003): obtenção no SUBNET, armazenamento,
  **renovação a cada 24 h**, e o que fazer quando ela falha — comportamento que a documentação apurada
  **não define**. É o risco aceito mais aberto do mapa.
- **Runbook de incidente.** O ticket 29 aceitou **alertas sem notificação**, então todo incidente
  começa por alguém olhando o painel-resumo. Escrever o que se faz a partir de cada sinal daquela tela:
  varredura parada, execuções fechadas pela varredura, `ALERTA` recorrente, ocupação do bucket subindo.
- **Rollback.** Imagem anterior, migração de schema já aplicada — o Flyway não desfaz. Decidir se há
  rollback ou só roll-forward, e o que isso exige das migrações.

## Notas de tickets anteriores

- **Ticket 28**: o `readiness` cai após N falhas consecutivas e volta na primeira que passa; o
  `retries` do Compose **não** basta porque o health check do Traefik reage à primeira falha.
- **Ticket 19**: uma imagem por módulo, com risco aceito de **divergência de versão do Jasper** entre
  elas, contido por comparação que alerta sem recusar. O deploy é onde essa divergência nasce.
- **Ticket 37**: `imagem_origem` é gravada em cada Execução. É o elo que liga um artefato ao commit —
  e só funciona se o deploy fixar SHA.

## Answer

### O quadro

| | |
|---|---|
| Rollback | **não existe procedimento** — existe propriedade das migrações |
| Deploy | **script idempotente versionado**, SHA como parâmetro obrigatório |
| Passos não automatizáveis | o script **confere e falha alto** |
| Runbook | estruturado pelos **sinais do painel-resumo** |

### Rollback não é procedimento, é propriedade das migrações

O Flyway não desfaz, e sem registry a imagem anterior pode nem existir. A saída não é construir um
procedimento de volta — é fazer com que **não seja preciso um**:

> **Toda migração é aditiva e compatível com a imagem anterior.** Coluna nova sempre nula, nunca `DROP`
> nem rename no mesmo release. Assim "voltar" é redeployar o SHA anterior **sem tocar no banco**.

Custa disciplina: renomear coluna vira dança de dois releases — adiciona a nova, migra os dados e
escreve nas duas; só no release seguinte remove a antiga. **Isso entra na lista de cenários
obrigatórios do ticket 46**, senão é combinado que se esquece exatamente no release apertado.

Rollback com restore de banco foi recusado por transformar **perda de dado em procedimento de rotina**:
toda Execução e todo Download desde o backup somem, num sistema em que o ticket 20 já tornou o
reprocessamento destrutivo.

Guardar as N imagens anteriores na VM **não é alternativa, é complemento** — resolve a metade das
imagens e nada da metade do schema. Vale fazer, porque torna o redeploy do SHA anterior instantâneo em
vez de exigir rebuild, e o rebuild é justamente o passo que pode não reproduzir.

### O deploy é script, e o SHA é parâmetro

```
deploy.sh <sha>
  1. git checkout <sha>  +  build das imagens na VM
  2. Flyway por natureza de schema (ticket 06) — migrações aditivas
  3. --publicar-inventario por módulo processador (ticket 04)
  4. restart, respeitando o readiness amortecido (ticket 28)
  5. confere o que não automatiza, e falha alto
```

Idempotente, então rerodar é seguro. Vive no repositório, logo é revisado e versionado como código. E o
SHA vira **parâmetro obrigatório em vez de disciplina** — o ticket 30 exigiu "SHA ou tag, nunca `main`
HEAD" e um script sem argumento simplesmente não roda.

> Isso é o que dá sentido ao `imagem_origem` que o ticket 37 grava em cada Execução: o hash da definição
> aponta para o git, e só chega lá se o deploy tiver fixado o commit.

Procedimento manual foi recusado com o argumento que o próprio mapa produziu: o ticket 38 registrou que
um passo de runbook pulado **desliga o onboarding em silêncio**, com sintoma aparecendo semanas depois.
Ansible foi recusado por trazer ferramenta nova a uma stack que o ticket 11 manteve enxuta, para duas ou
três VMs em Compose.

### O que o script confere sem automatizar

Mesmo padrão da verificação de leitura do ticket 38: não tenta fazer, mas **recusa seguir em silêncio**.

| | origem |
|---|---|
| Chave do AIStor válida | ADR 0003 — renovada a cada 24 h, comportamento na falha **não documentado** |
| Árvore de Grupos, com `PENDENTES` como Default Group | ticket 38 — o `--import-realm` é pulado em realm existente |
| Mailpit de pé, com volume persistente | ticket 47 |
| Allowlist do Traefik cobrindo Account Console, `/realms/` e a UI do Mailpit | tickets 17 e 47 |

**A chave do AIStor é o risco mais aberto do mapa** e continua aberto: a documentação apurada não define
o que acontece quando a renovação falha. O script confere que ela está válida no momento do deploy —
não protege contra ela expirar depois.

### O upgrade do Keycloak tem lista própria

O `--import-realm` é **pulado** em realm existente (ticket 07), então tudo que se acumulou como
configuração viva precisa ser reaplicado à mão ou pelo script:

- allowlist do Traefik (ticket 17) — falha **fechada** por decisão, então rota nova de versão futura
  nasce bloqueada e pode quebrar função legítima
- permissões de FGAP e o escopo do service account (tickets 14 e 38)
- Default Group `PENDENTES` (tickets 16 e 38)
- features desabilitadas no realm e Account Console enxugado (ticket 17)
- tema de e-mail (ticket 47)

**O upgrade dispara o E2E completo** (decidido no ticket 30, e a razão está aqui: nenhum desses itens é
verificável por leitura de configuração).

### O runbook segue os sinais do painel-resumo

O ticket 29 aceitou **alertas sem notificação**, então todo incidente começa por alguém olhando aquela
tela. O runbook não se organiza por componente — se organiza pelo que a tela mostra.

| sinal | o que significa | primeira ação |
|---|---|---|
| `varredura_idade_segundos` alto | a DAG de varredura parou ou está pausada (ticket 36) | ver se a DAG está ativa; Execuções abertas acumulam em silêncio |
| Execuções fechadas pela varredura > 0 | infraestrutura falhou sem avisar (ticket 02) | achar o worker ou a VM que caiu |
| `ALERTA` recorrente no mesmo Código | degradação gradual ou estimativa defasada (ticket 24) | comparar `inicio_processamento`; ver se é volume ou partida |
| Ocupação do bucket subindo sem estabilizar | lifecycle não está alcançando algo (ticket 27) | conferir a regra e procurar objeto órfão |
| `inventario_divergente` | imagem subiu sem `--publicar-inventario` (ticket 37) | rerodar o passo de bootstrap |
| Transições de `readiness` sem incidente de banco | amortecimento curto demais (ticket 28) | rever `falhasParaCair` e o `connection-timeout` |
| Cadastro parado no `PENDENTES` | ninguém repassou o link do Mailpit (ticket 47) | abrir a UI do Mailpit e repassar |

### Derivado

- **Persistência do Mailpit em volume** (ticket 47): ele guarda em memória por padrão, e um restart apaga
  links de verificação pendentes — quem esperava o repasse recomeça o cadastro do zero.
- **A ordem do bootstrap importa**: o `--publicar-inventario` roda **depois** da migração do schema de
  controle, porque escreve em `jrxml_publicado` (ticket 04).
- **O script não é gate de qualidade.** O CI já parou no teste (ticket 30, risco aceito); o script
  garante *o quê* e *em que ordem*, não *se está bom*.

## Notas do ticket 49 (dimensionamento e capacidade)

- **Entrada nova no runbook**: API reiniciando sozinha sob carga de exportação é sintoma de **OOM** — o
  ticket 49 aceitou não ter teto, e a exportação roda na JVM da API sem isolamento (ADR 0002). A
  primeira ação é olhar o **tamanho do artefato pedido**, não a métrica de latência.
- **O restore não é ensaiado** (risco aceito no ticket 49), então o procedimento escrito aqui é
  executado pela primeira vez sob pressão. Vale que ele seja mais explícito do que seria necessário para
  um procedimento exercitado.
- **Uma VM só**: a ordem de subida do `deploy.sh` passa a importar mais, porque não há separação física
  entre o que tem estado e o que não tem.
