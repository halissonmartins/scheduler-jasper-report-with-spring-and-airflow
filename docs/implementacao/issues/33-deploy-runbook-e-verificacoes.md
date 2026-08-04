# 33 — `deploy.sh`, runbook e verificações do repositório de produção

**O que construir:** o caminho para produção e o que se faz quando quebra. Duas propriedades
carregam este ticket: **rollback não é procedimento, é propriedade das migrações**; e o que o script
não automatiza, ele **confere e falha alto** — porque um passo de runbook pulado desliga o
onboarding em silêncio, com sintoma aparecendo semanas depois.

**Bloqueado por:** 24, 30, 32.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] `deploy.sh` idempotente e versionado, com o SHA como **parâmetro obrigatório em vez de
      disciplina** — sem registry, o commit é o único elo entre o que foi testado e o que roda, e um
      script sem argumento simplesmente não roda.
- [ ] A ordem é fixa: checkout e build → migrações por natureza de schema → publicação do inventário
      → restart respeitando o readiness amortecido → conferências.
- [ ] `CO-MIGRACAO-ADITIVA-IMAGEM-ANTERIOR` — aplicar as migrações do SHA novo e subir o container do
      SHA **anterior** contra esse banco. É o que substitui o rollback, e sem estar na lista
      executável é combinado que se esquece exatamente no release apertado.
- [ ] Toda migração é aditiva: coluna nova sempre nula, nunca remoção nem renomeação no mesmo
      release. Renomear vira dança de dois releases.
- [ ] O script **confere e falha alto**, sem tentar automatizar: chave de licença válida, árvore de
      Grupos com o grupo padrão marcado, Mailpit de pé com volume, e a allowlist cobrindo console de
      conta, protocolo e a UI do Mailpit.
- [ ] Lista própria de reaplicação no upgrade do provedor de identidade — o import de realm é pulado
      em realm existente, então allowlist, permissões, grupo padrão, features e tema precisam ser
      reaplicados.
- [ ] Limites de memória por container: com uma VM só, são a única separação entre a API — cujo
      estouro de memória foi aceito como alcançável por uso ordinário — e o banco.
- [ ] O runbook se organiza **pelos sinais do painel-resumo**, não por componente, porque todo
      incidente começa por alguém olhando aquela tela. Cobre: varredura parada, Execuções fechadas
      pela varredura, alerta recorrente, ocupação do bucket subindo, inventário divergente,
      transições de readiness sem incidente, cadastro parado na fila, e API reiniciando sob carga de
      exportação (sintoma de estouro de memória — a primeira ação é olhar o **tamanho do artefato
      pedido**, não a latência).
- [ ] As seis verificações contra o servidor de objetos de produção têm **dono e momento definidos**:
      lifecycle com filtro vazio, header de expiração, ausência de permissão de apagar, ausência de
      permissão de listar na credencial da API, expurgo de objeto órfão, e imagem ARM64. Não são
      teste automatizado — o CI não tem chave, de propósito.
- [ ] Fica registrado que o **restore não é ensaiado**: o procedimento é executado pela primeira vez
      sob pressão, então precisa ser mais explícito do que seria necessário para um exercitado.
