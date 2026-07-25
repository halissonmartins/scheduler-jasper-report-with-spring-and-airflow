# 14 — Autocadastro de Relator

**What to build:** Um Relator cria a própria conta pela interface pública, confirma o e-mail e passa a aguardar liberação — sabendo disso por uma mensagem clara. Enquanto não recebe Role de Relatório, a conta não faz nada.

**Blocked by:** 01 — Realm do Keycloak e autenticação da API.

**Status:** ready-for-agent

- [ ] Cadastro público disponível, criando usuário do tipo RELATOR
- [ ] Verificação de e-mail obrigatória antes de a conta ser utilizável
- [ ] Proteção contra bots ativa no formulário de cadastro, junto com política de senha e detecção de força bruta (ADR-0010)
- [ ] Recuperação de senha por e-mail funcionando
- [ ] Conta sem nenhuma Role de Relatório autentica, recebe catálogo vazio e é recusada em qualquer geração
- [ ] Cenários cobrindo cadastro, verificação pendente e conta sem role
