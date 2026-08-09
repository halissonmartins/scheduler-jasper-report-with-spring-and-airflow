# 01 — Fundações do mono repositório e CI verde

**O que construir:** os trilhos, antes de qualquer funcionalidade. Ao fim deste ticket, um clone
limpo numa máquina nova instala, compila, testa e passa no CI com três comandos, e todo módulo
declarado em RA-02 a RA-06 existe como esqueleto que compila — biblioteca comum, starter do
processador, os cinco processadores, a API e o frontend. Nada faz nada ainda; o que este ticket
entrega é o chão em que os outros 34 pisam.

**Bloqueado por:** nada — pode começar imediatamente.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Mono repositório com **versão única** (RA-01). Todos os módulos compartilham o mesmo ciclo de
      versão e as mesmas dependências — é a premissa de que dependem os trade-offs da serialização
      do artefato renderizado.
- [ ] Todos os módulos de RA-02 a RA-06 compilam, inclusive os cinco processadores, cada um já
      nomeado pela sigla do seu produto (RA-04).
- [ ] Scripts padronizados de `setup`, `dev`, `test`, `lint`, `build` e `migrate`, e um `README.md`
      que roda o projeto em três comandos.
- [ ] Lint, formatter e tipagem estrita configurados e **bloqueantes**; `.editorconfig` no
      repositório.
- [ ] CI no GitHub Actions bloqueante por PR (RA-53): lint + tipos + testes + build.
- [ ] `.gitignore` e scanner de segredos no CI; `.env.example` com todas as variáveis e **nenhum**
      segredo real.
- [ ] `ARCHITECTURE.md` esquelético na raiz: visão geral, estrutura pretendida e os invariantes que
      já saíram dos ADRs — `catchup=False`, `queryTimeout`, a convenção de autoria do JRXML, quem
      escreve no schema de controle, o teto por produto e o semáforo de exportação.
- [ ] Cobertura com JaCoCo ligada (RA-49), ainda que a suíte esteja quase vazia.
- [ ] O CI roda num clone limpo, sem estado da máquina de quem escreveu.
