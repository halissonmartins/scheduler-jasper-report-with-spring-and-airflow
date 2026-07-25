# 15 — Frontend do Relator

**What to build:** A experiência completa do Relator no navegador: entra com sua conta, vê os Relatórios que pode gerar agrupados por Produto, escolhe uma das datas disponíveis em dd/MM/yyyy, escolhe o formato e baixa o arquivo — com indicação de progresso durante a espera e mensagem clara quando o volume excede o limite.

**Blocked by:** 11 — Geração em PDF, XLSX e DOCX.

**Status:** ready-for-agent

- [ ] Login e logout via Keycloak com Authorization Code + PKCE
- [ ] Cliente da API gerado a partir do OpenAPI, sem fixtures mantidas à mão (ADR já decidido na sessão; Json Server descartado)
- [ ] Catálogo mostra apenas os Relatórios das Roles do usuário, agrupados por Produto
- [ ] Seletor de data oferece apenas Datas de Referência disponíveis, exibidas em dd/MM/yyyy, no máximo sete
- [ ] Seleção de Formato de Exportação entre os quatro formatos
- [ ] Download por fetch com header de autorização, materializando o arquivo no navegador (ADR-0004)
- [ ] Indicação visível de progresso enquanto a geração ocorre
- [ ] Recusa por limite exibida como mensagem compreensível, com limite e contagem, não como erro técnico
- [ ] Recusa por permissão exibida como orientação para procurar o Gerente
- [ ] Link para o Account Console para troca de senha
