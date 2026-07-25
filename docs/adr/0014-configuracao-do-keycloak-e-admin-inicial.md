# Configuração do Keycloak: realm versionado, script de convergência e ADMINISTRADOR inicial

O realm é versionado em `deploy/keycloak/` como JSON e cobre o primeiro boot: clients (frontend público com Authorization Code + PKCE, `api` como bearer-only), realm roles ADMINISTRADOR/GERENTE/RELATOR, self-registration, verificação de e-mail, reCAPTCHA, detecção de força bruta, política de senha e Account Console. Um script `kcadm.sh` idempotente, também versionado, roda a cada deploy e aplica as alterações posteriores.

O script existe por um fato do produto: `--import-realm` no startup **ignora realms já existentes**, então o JSON é estratégia de instalação, não de configuração. Sem o script, toda mudança pós-produção seria um clique no console que não existe no git, e os ambientes divergiriam silenciosamente.

A troca de senha de qualquer tipo de usuário (linha 31 da descrição inicial) é atendida pelo **Account Console** do Keycloak — não há tela nem endpoint próprios.

## Consequências (risco aceito)

- O ADMINISTRADOR inicial segue a linha 29 da descrição ao pé da letra: criado com senha vinda de variável de ambiente, **sem rotação obrigatória no primeiro login**. A senha inicial permanece válida indefinidamente e reside no `.env` do host. Combinado com o ADR-0010 (exposto à internet, sem MFA), essa única senha é a chave dos Cadastros e da gestão de usuários.
- Higiene mínima obrigatória: `.env` no `.gitignore` e troca manual da senha inicial documentada no runbook de implantação.
- O admin de bootstrap do Keycloak (`KC_BOOTSTRAP_ADMIN_USERNAME`/`KC_BOOTSTRAP_ADMIN_PASSWORD`, realm master) é infraestrutura e não se confunde com o ADMINISTRADOR da aplicação, que vive no realm da aplicação.
