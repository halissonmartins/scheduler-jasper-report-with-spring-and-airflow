# 47 — Fluxos de e-mail, Mailpit e templates do Keycloak

Type: grilling
Status: open
Blocked by: —

## Question

Quais e-mails o sistema dispara, com que aparência, e como isso é testado?

Graduou da névoa quando o ticket 16 decidiu o que **não** existe: não há e-mail de aviso ao GERENTE
quando alguém se cadastra — só o contador do `PENDENTES`. O que sobra é menor e mais nítido.

Decidir:

- **A lista fechada de e-mails.** Verificação de endereço (obrigatória, ticket 16) e redefinição de
  senha (Account Console, ticket 17) são os dois certos. Há outros? Convite, aviso de vínculo
  concedido, aviso de exclusão de RELATOR (ticket 14 decidiu que a exclusão é definitiva)?
- **Quem dispara.** Todos saem do **Keycloak**, ou algum sai da API? Se algum sair da API, ela ganha
  dependência de SMTP e um modo de falha novo — e o ticket 28 decidiu quem entra no readiness.
- **Configuração do Mailpit** em dev e CI, e o que roda em produção. Mailpit é ferramenta de
  desenvolvimento; produção precisa de relay real, ou o sistema roda sem e-mail?
- **Templates e tema.** O Keycloak permite tema próprio para e-mail. Decidir se há um, o que ele
  carrega (marca, idioma pt-BR, remetente) e onde ele vive — lembrando que o ticket 07 registrou que
  **import de realm é semente, não configuração declarativa**, então tema aplicado por import não
  volta num realm existente.
- **Teste.** O ticket 30 classifica por infraestrutura necessária: e-mail exige Mailpit de pé, então
  cai na camada de aceitação. Decidir quais cenários valem — "cadastro público dispara verificação" é
  o candidato óbvio.
- **O que acontece quando o e-mail falha.** Verificação obrigatória mais SMTP fora significa cadastro
  que nunca completa. Isso é visível em algum lugar, ou o usuário simplesmente espera?

## Notas de tickets anteriores

- **Ticket 16**: a listagem do GERENTE filtra `emailVerified`, e Default Group é aplicado na **criação**
  — então cadastros não verificados entram no `PENDENTES` e ficam **invisíveis**, acumulando sem
  expiração. Um e-mail de verificação que não chega produz exatamente esse estado.
- **Ticket 38**: o contador bruto de membros do `PENDENTES` diverge da tela por construção, justamente
  por causa desse filtro.
- **Ticket 29**: não há canal de notificação — os alertas ficam no painel. Se algum e-mail deste ticket
  for operacional (e não de usuário), ele seria a primeira exceção a essa decisão e precisa dizer por quê.
