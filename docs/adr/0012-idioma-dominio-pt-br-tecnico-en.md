# Domínio em português, técnico em inglês

Tipos e campos de domínio usam as palavras do negócio (`Relatorio`, `Produto`, `RoleDeRelatorio`, `CodigoRelatorio`, `StatusProcessamento`, `tempoEstimadoExecucao`); o andaime técnico permanece em inglês (`Repository`, `Controller`, `Config`, `Client`). `CONTEXT.md` e os ADRs são escritos em pt-BR.

Registrado porque o padrão óbvio seria tudo em inglês, e um leitor futuro tenderia a "corrigir" os nomes. Traduzir o domínio inseriria uma camada de tradução entre o que um Gerente diz e o que o código diz — é exatamente o que a linguagem ubíqua do `CONTEXT.md` existe para evitar (relator é Relator, não Reporter nem Requester).
