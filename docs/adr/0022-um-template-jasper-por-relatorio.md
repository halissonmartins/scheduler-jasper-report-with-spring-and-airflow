# Um template Jasper por Relatório

Cada Relatório tem o seu próprio `.jrxml`, versionado no repositório e associado ao Relatório pelo Código do Relatório. Não há template genérico: um Relatório sem template não pode ser gerado em PDF, XLSX ou DOCX, e a API recusa a Geração com mensagem explícita em vez de produzir arquivo vazio. CSV não usa template (ADR-0021).

Escolhido pelo controle de layout: cabeçalho, formatação por coluna e apresentação por Relatório, que um template tabular genérico não entrega.

## Consequências

- **A história 61 fica parcialmente revogada.** "Cadastrar um novo Relatório sem deploy" continua verdadeiro para a **Coleta** — as DAGs são geradas do Cadastro (ADR-0007) e os dados passam a ser coletados sem release. Mas a **Geração** nos três formatos do Jasper passa a exigir autoria do `.jrxml` e um release. Cadastrar Relatório deixou de ser uma operação puramente administrativa e virou administração mais desenvolvimento.
- Existe uma janela em que um Relatório está cadastrado, coletando dados diariamente e ocupando disco sob a retenção do ADR-0018, mas não é gerável em PDF/XLSX/DOCX. A recusa explícita existe para que essa janela seja visível em vez de silenciosa.
- O ADR-0002 escolheu MongoDB pela liberdade de esquema, para que cadastrar Relatório não exigisse migração. O template reintroduz, no caminho da Geração, o acoplamento que a escolha do banco evitou no caminho da Coleta. É consciente: o preço é pago em release de template, não em migração de banco.
- Cinco Produtos com até 9999 Relatórios cada (ADR-0015) é um teto teórico de templates. Na prática, cada Relatório novo é trabalho de design — o crescimento do catálogo passa a ter custo linear em esforço humano.
- Se o volume de Relatórios crescer a ponto de tornar isso insustentável, o caminho de volta é acrescentar um template genérico como padrão, mantendo o específico como exceção. Reabrir este ADR é a forma de fazê-lo.
