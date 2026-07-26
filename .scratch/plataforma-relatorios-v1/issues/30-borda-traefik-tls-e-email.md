# 30 — Borda: Traefik, TLS e e-mail

**What to build:** A borda que os ADRs pressupunham e ninguém tinha construído. Traefik termina TLS, publica só o que é público e concentra o timeout de leitura de que o ADR-0004 depende; o Mailpit recebe os e-mails do Keycloak (ADR-0020).

**Blocked by:** 01 — Realm do Keycloak e autenticação da API.

**Status:** ready-for-agent

- [ ] Traefik no Compose com descoberta por labels, terminando TLS por ACME/Let's Encrypt
- [ ] Apenas frontend e API recebem rota pública; Airflow, Jaeger, Grafana e Prometheus não têm regra de ingress (ADR-0009, ADR-0017)
- [ ] Timeout de leitura configurado acima do pior caso de Geração, com o valor e o motivo registrados no runbook (ADR-0004)
- [ ] Cenário provando que o timeout mal configurado trunca o download — é o modo de falha que entrega arquivo corrompido em vez de erro
- [ ] Rate limiting no formulário de cadastro público (ADR-0010)
- [ ] Mailpit no Compose, com o Keycloak apontado para ele por variável de ambiente
- [ ] Verificação de e-mail do ticket 14 comprovada ponta a ponta lendo a mensagem capturada pelo Mailpit
- [ ] Runbook declara que, com Mailpit como destino final, produção não entrega e-mail: não há autocadastro nem recuperação de senha até um relay real ser configurado (ADR-0020)
- [ ] Chaves do reCAPTCHA no `.env`, com a proteção desligada em dev e teste (ADR-0020)
