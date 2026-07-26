# 25 — Runbook, `.env` e Compose de produção

**What to build:** O sistema completo sobe de forma reproduzível em uma máquina nova, e o que não está no código está no runbook. Ticket de integração final: é aqui que se verifica que as partes construídas separadamente funcionam juntas.

**Blocked by:** 12, 14, 17, 18, 19, 20, 21, 24, 26 e 27 — todos os tickets folha (16 e 23 chegam pelo 26; 22 chega pelo 27).

**Status:** ready-for-agent

- [ ] Compose completo sobe PostgreSQL, MongoDB, Keycloak, API, Airflow, Collector, backend de métricas, Jaeger, Grafana e frontend
- [ ] `.env` incluído no `.gitignore` e ausente do histórico do repositório
- [ ] Runbook documenta a troca manual da senha inicial do ADMINISTRADOR, obrigatória por não haver rotação forçada (ADR-0014)
- [ ] Runbook documenta que o timeout de leitura do ingress precisa ficar acima do pior caso de geração, sob pena de download truncado (ADR-0004)
- [ ] Runbook documenta que a interface do Airflow não é exposta e como acessá-la pela rede interna (ADR-0009)
- [ ] Runbook documenta o replica set do MongoDB, a rotina de backup e o teste de restauração, todos artesanais no Compose (ADR-0009)
- [ ] Runbook documenta o volume Badger do Jaeger — backup, restauração e o fato de que perdê-lo perde o histórico de traces, sem HA (ADR-0017)
- [ ] Runbook documenta como partir de um erro relatado pelo usuário até o trace correspondente no Jaeger (ADR-0017)
- [ ] Runbook lista os riscos aceitos vigentes com o ADR correspondente, para quem operar saber o que é deliberado
- [ ] Verificação de ponta a ponta em ambiente limpo, ADMINISTRADOR: entra com a senha inicial do `.env` e a troca (ADR-0014), cadastra Produto, cadastra Relatório com Código válido, altera nome/descrição/Tempo Estimado/Janela de Agendamento, é recusado ao remover Produto com Relatórios, cria um usuário GERENTE
- [ ] Verificação de ponta a ponta em ambiente limpo, GERENTE: cria Role de Relatório com nome e descrição, vincula o Relatório a ela, vincula a Role a um Relator recém-cadastrado pela interface pública, lista Relatores e vínculos, desvincula e vê o acesso cair de imediato, é recusado ao tentar criar GERENTE
- [ ] Verificação de ponta a ponta em ambiente limpo: Coleta agendada dispara, dados chegam, Relator gera e baixa, auditoria registra
