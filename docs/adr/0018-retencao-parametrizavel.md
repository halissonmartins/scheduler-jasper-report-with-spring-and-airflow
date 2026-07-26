# Retenção parametrizável, com teto e três relógios separados

A retenção deixa de ser o literal `7` espalhado pelo código e passa a ser configuração, em **três parâmetros independentes**: linhas coletadas no MongoDB (padrão 7 dias), traces no Jaeger e logs no Loki (padrão 14 dias). O parâmetro dos dados tem **teto de 30 dias** validado na subida — acima disso a aplicação recusa iniciar, com mensagem apontando para este ADR.

Tudo que hoje escreve "sete" deriva do parâmetro: o índice TTL, a quantidade de Datas de Referência oferecidas pela API e o seletor do frontend.

Registrado porque os quatro números iguais eram coincidência, não decisão. Os relógios de diagnóstico e o de dados têm donos e motivos diferentes: telemetria quer janela **maior** que os dados — incidente se investiga depois do fato — e, por regra do ADR-0017, não carrega linha de Relatório, sendo material menos sensível.

## Considered Options

- **Um parâmetro único para as três retenções** — recusado. Amarra a janela de diagnóstico à de dado sensível, que é o acoplamento que este ADR existe para desfazer.
- **Retenção por Relatório, no Cadastro** — recusada para o v1, mas o caminho fica registrado porque a pergunta vai voltar: índice TTL não varia por documento com `expireAfterSeconds: N`; faz-se gravando um `expiresAt` calculado em cada documento e criando o índice com `expireAfterSeconds: 0`. O custo real não é esse — é que a retenção vira dado do documento (mudar o Cadastro não afeta o já gravado sem backfill) e "no máximo N datas" passa a variar por Relatório, atravessando API e tela.
- **Sem teto** — recusado. Ver consequências.

## Consequências

- **O teto existe por causa do ADR-0016.** Sem classificação de dados e sem criptografia em repouso, e com a aplicação na internet (ADR-0010), a retenção curta é de fato a única coisa que limita a janela de exposição de dado pessoal e financeiro. Sem teto, essa mitigação seria removível por variável de ambiente, sem revisão e sem deixar rastro em decisão nenhuma. Passar de 30 dias é uma escolha que pertence ao ADR-0016, não ao operador.
- **Reconciliação obrigatória na subida.** `expireAfterSeconds` de índice TTL existente não muda por redeclarar o índice — exige `collMod`. Sem esse passo o parâmetro funcionaria em ambiente novo e seria silenciosamente ignorado em ambiente existente: o operador altera a variável, reinicia, vê o sistema subir limpo e acredita que mudou a retenção. Um parâmetro que mente é pior que um literal.
- **A postura de produto do ADR-0008 não muda.** Aumentar a retenção permite gerar um Relatório de uma Data de Referência mais antiga; **não** cria relatório de fechamento, que é agregação entre dias e não existe em parte alguma do desenho. Quem subir o parâmetro para 30 esperando fechamento de mês não vai obtê-lo.
- Custo de disco e tamanho do índice composto crescem com a janela. A taxa de deleção do TTL, não: em regime estacionário ela iguala a de escrita qualquer que seja a retenção, então a concorrência apontada no ADR-0002 não piora.
- Três parâmetros a mais no `.env` e no runbook, cada um com seu padrão e seu motivo.
