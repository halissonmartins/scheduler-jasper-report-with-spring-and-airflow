# 47 — Fluxos de e-mail, Mailpit e templates do Keycloak

Type: grilling
Status: resolved
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

## Answer

### O quadro

| | |
|---|---|
| Produção | **Mailpit**, com repasse manual pelo operador (risco aceito) |
| Quem dispara | **só o Keycloak** |
| A lista | verificação de endereço e redefinição de senha — nada mais |

### Risco aceito: Mailpit em produção

O Mailpit **captura**, não entrega. A alternativa de relay SMTP externo foi apresentada com a cadeia de
consequências completa e **recusada**, em favor de não introduzir credencial nem dependência externa.
Fica registrado o que se aceita junto — e é mais do que "e-mails não saem".

**1. O cadastro deixa de ser autoserviço.** O ticket 16 decidiu verificação **obrigatória** e recusou
allowlist por domínio justamente porque *"RELATOR só existe por cadastro público"*. Sem entrega, o
candidato se cadastra, o Default Group o põe no `PENDENTES`, e ele nunca verifica — a listagem do
GERENTE filtra `emailVerified`, então ele fica **invisível**. O contador do `PENDENTES`, único sinal do
sistema, passa a contar gente que ninguém enxerga pela tela.

**2. Não há recuperação de senha sem o operador.** O ticket 17 mandou a troca para o Account Console e o
ticket 07 recusou `manage-users` no service account exatamente para que ninguém pudesse redefinir a
senha de outro. Sem o repasse, quem esquece a senha não tem caminho de volta — nem próprio, nem
administrativo. Nenhum dos dois tickets previu que o e-mail não sairia.

**3. A UI do Mailpit vira porta de tomada de conta.** Ela contém links de verificação e de redefinição
de senha em texto claro. Em desenvolvimento ela fica aberta; em produção **não pode**. Entra na
allowlist do Traefik (ticket 17) com autenticação própria, e passa a ser superfície a proteger com o
mesmo cuidado do Account Console.

> **O procedimento fica no runbook** (ticket 48): abrir a UI do Mailpit, localizar o e-mail pelo
> destinatário, repassar o link por fora. É passo manual, e o ticket 38 já registrou o que passo manual
> custa — o sintoma de esquecê-lo aparece semanas depois, como alguém que se cadastrou e nunca recebeu
> acesso.

### Só o Keycloak, e só dois e-mails

**A API não fala SMTP.** Não ganha modo de falha novo, não vira candidata a entrar no `readiness`
(ticket 28), e não precisa de configuração de mail em ambiente nenhum.

Avisos de negócio pela API — vínculo concedido, exclusão de RELATOR — foram recusados porque o RELATOR
**descobre no próximo login**: os relatórios simplesmente aparecem. Trocar isso por dependência de SMTP
mais trabalho manual de repasse é pagar caro por um aviso que a tela já dá.

Aviso ao GERENTE sobre o `PENDENTES` foi recusado de novo (o ticket 16 já o havia recusado), e agora com
um argumento novo: o operador visita o Mailpit **para achar links acionáveis**, e cada aviso sem link é
uma linha a mais para filtrar antes de achar o que importa.

### O tema de e-mail mudou de público

O leitor principal deixou de ser o destinatário e passou a ser o **operador varrendo uma caixa**.

Isso inverte o que o template deve otimizar: o assunto precisa carregar **para quem é** e **qual é a
ação** — `Verificação de e-mail — fulano@exemplo.com` —, e não marca. Marca é o que menos importa num
e-mail que nunca sai do Mailpit.

**O tema é configuração viva** que o `--import-realm` não reproduz em realm existente (ticket 07).
Entra na lista de reaplicação do ticket 48, ao lado da allowlist do Traefik e das permissões de FGAP.

### Derivado

- **Mailpit em dev, CI e produção** — é a mesma peça nos três, o que remove uma divergência de ambiente
  em vez de criar (ao contrário do ADR 0003, onde CI e produção rodam servidores S3 diferentes).
- **Cenário obrigatório**: cadastro público dispara o e-mail de verificação, verificado contra o Mailpit
  de pé. Camada de aceitação (ticket 30), com identificador na lista executável do ticket 46.
- **Falha do Mailpit não tem sinal.** Com ele local a falha é improvável, mas se estiver fora o cadastro
  trava sem sintoma — o ticket 29 não deu canal de notificação, e este ticket **não abre exceção**.
- **Retenção do Mailpit**: ele guarda em memória por padrão. Um restart apaga links de verificação
  pendentes, e quem esperava o repasse recomeça o cadastro. Vale persistência em volume, e é decisão do
  ticket 48.
