# 01 — Glossário do domínio, linguagem ubíqua e nomes dos módulos

Type: grilling
Status: resolved
Blocked by: —

## Question

Qual é a linguagem ubíqua deste sistema, e como os módulos se chamam?

Fixar os termos que todo o resto do mapa vai usar, e escrever a decisão como modelo de domínio (use `/domain-modeling`):

- **Produto** × **Relatório** × **Código de Relatório** × **Execução** × **Artefato** × **Data de referência** — cada um precisa de definição e de identidade própria. Hoje "relatório" designa tanto o cadastro (com tempo estimado, nome, descrição) quanto o resultado de uma execução, e isso vai vazar para o schema e para a API.
- **Perfil de usuário** (ADMINISTRADOR / GERENTE / RELATOR) × **Role de Relatório** × **Grupo** — três conceitos de autorização com nomes que se confundem. "Role" hoje é usado para os dois.
- O código do relatório é `^[A-Z]{1,20}-\d{4}$`. Falta decidir: a sequência de 4 dígitos é única **por produto** ou **global**? O código é imutável? Qual a relação normativa entre "nome do produto" exibido e o prefixo normalizado (`Conta Corrente` → `CONTACORRENTE`, `Poupança` → `POUPANCA`)?
- Renomear um produto quebra o histórico, porque o nome está no código **e** no path do MinIO. Decidir se o código é imutável e o nome apenas um rótulo.

E os nomes concretos dos artefatos Maven (pendência explícita do documento: "Definição dos nomes dos módulos"):

- biblioteca comum
- starter do processador com Spring Batch
- API REST
- os 5 módulos processadores
- o módulo frontend

Definir groupId, artifactId e o padrão de nomenclatura de pacotes.

## Answer

A linguagem ubíqua foi escrita em [`CONTEXT.md`](../../../CONTEXT.md) (glossário completo, com
listas de termos a evitar). O ponto mais caro do ticket foi separar as duas coisas que o
documento chamava de "relatório":

- **Relatório** passa a significar apenas a **definição cadastrada** (Código, nome, descrição,
  tempo estimado, JRXML). Existe uma vez.
- **Execução** é a rodada da Coleta para o par (Relatório, Data de Referência). Tem status,
  início e fim. É o que o drop-down lista quando bem-sucedida.
- **Artefato** é cada arquivo produzido por uma Execução (`.jrprint`, `.csv.gz`). Expira pela
  retenção; os metadados da Execução sobrevivem a ele.
- **Exportação** é a conversão sob demanda de um Artefato para o formato pedido; **Download** é
  a entrega registrada em histórico.

O research 06 confirmou que a "estrutura com os dados não estruturados" da descrição inicial são
os Artefatos no repositório, não linhas de banco — o banco guarda só metadados.

No eixo de autorização, "role" fazia dois trabalhos e agora está proibido sozinho:

- **Perfil** — `ADMINISTRADOR` / `GERENTE` / `RELATOR`. Conjunto fechado de três, no código, não
  administrável.
- **Role de Relatório** — conjunto aberto, criado pelo GERENTE, sob o prefixo reservado `REL_`.
- **Grupo** — conjunto de RELATORes. Cadeia: Relatório ← Role de Relatório ← Grupo ← Usuário.
- **Pendente de Vínculo** — RELATOR cadastrado e ainda sem Grupo.

Como Perfil e Role de Relatório passam a ser conceitos nomeadamente distintos, o risco de
escalonamento do **ticket 14** fica explícito em vez de escondido: o prefixo `REL_` é a fronteira,
e o ticket 14 decide quem a impõe.

**Sigla do Produto** virou dado próprio, imutável e único — não derivação do Nome. Registrado no
[ADR 0001](../../adr/0001-sigla-do-produto-imutavel.md), porque é caro de reverter (a sigla está em
cada Código e em cada caminho de Artefato) e um leitor futuro perguntaria por que existe o campo.
O **Nome do Produto** passa a ser rótulo mutável, o que torna renomear seguro.

A **sequência de 4 dígitos é única por Produto** (teto de 9.999 por Produto). Global capearia o
sistema inteiro em 9.999 sem ganho, e os exemplos da descrição inicial já a tratavam como
independente por produto.

**Idioma e nomes dos módulos**: domínio em português, andaime técnico em inglês
(`Relatorio`, `ExecucaoRepository`, `ArtefatoService`). É o único esquema em que o código lê
igual ao glossário — e as Siglas (`POUPANCA`, `CONSORCIO`) já são portuguesas, então traduzir os
módulos criaria um `processor-savings` tratando códigos `POUPANCA-*`.

`groupId`: `br.com.relatorios`

```
relatorios-parent
  relatorios-comum
  relatorios-processador-starter
  relatorios-api
  relatorios-processador-poupanca
  relatorios-processador-cliente
  relatorios-processador-contacorrente
  relatorios-processador-consorcio
  relatorios-processador-emprestimo
  relatorios-web
```

### Aberto por consequência

- A **Data de Referência** hoje é o dia em que a Execução rodou, mas o nome sugere competência.
  O fuso continua indefinido — o ticket **03** decide, e pode renomear o termo.
- O research 10 alerta que o filtro de lifecycle do MinIO é prefixo literal sem wildcard: se a
  retenção precisar ser por Produto, a Sigla tem de vir **antes** da data no caminho. Entra no
  ticket **03**.
