# Exposição pública de toda a aplicação, sem MFA

O cadastro de Relatores é aberto na internet e todas as telas — inclusive as de Administrador e Gerente — respondem no mesmo ingress público. As roles do Keycloak são a única fronteira. Não há MFA; a proteção de credenciais é política de senha mais detecção de força bruta e bloqueio do Keycloak.

## Considered Options

- **Exposição segmentada** (público para cadastro/sign-in/Relator, rede interna para as telas privilegiadas) — recomendada e recusada.
- **MFA obrigatório para Administrador e Gerente** via required action do Keycloak — recomendado e recusado.

## Consequências (riscos aceitos)

- Uma falha de autorização em qualquer endpoint administrativo é explorável diretamente da internet.
- O formulário de login administrativo é alvo de credential stuffing, e uma senha de Administrador vazada ou reutilizada equivale ao comprometimento completo dos Cadastros e da gestão de usuários.
- Obrigatório em contrapartida: verificação de e-mail antes de a conta ser utilizável, proteção contra bots no formulário de cadastro (reCAPTCHA do Keycloak), rate limiting, política de senha, TLS + WAF e uma rotina de limpeza das contas que nunca recebem Role de Relatório.
- Atenuação existente: só um Relator com Role de Relatório vinculada alcança a Geração, então o endpoint caro não é um vetor de DoS anônimo.
- Duas exceções deliberadas, ambas por motivo próprio: a interface do Airflow (ADR-0009, execução remota de código pelo socket do Docker) e o plano de telemetria — Jaeger, Grafana, Prometheus (ADR-0017, agregam dado de todos os Produtos sem fronteira de Role de Relatório). "Todas as telas no ingress público" vale para as telas da aplicação, não para essas.
