# Templates compilados no build e resolvidos pelo classpath

Os `.jrxml` são compilados para `.jasper` durante o build do módulo `api` e empacotados no artefato. A API não compila template em runtime e não carrega template de fora do classpath. Um `.jrxml` inválido quebra o build, não a primeira Geração em produção.

O layout completo, sob a convenção do ADR-0022:

```
api/src/main/resources/relatorios/<PRODUTO>/<CODIGO>.jrxml      → <CODIGO>.jasper
api/src/main/resources/relatorios/<PRODUTO>/sub/<NOME>.jrxml    → sub/<NOME>.jasper
api/src/main/resources/relatorios/<PRODUTO>/img/<NOME>.<ext>    → copiado sem alteração
```

Subrelatórios e imagens são referenciados pelo **caminho de classpath completo** (`relatorios/POUPANCA/sub/movimento.jasper`), nunca por `SUBREPORT_DIR` ou caminho de disco. O engine resolve a location de um subrelatório, imagem ou style template tentando URL, arquivo em disco e recurso de classpath, nessa ordem; dentro do jar executável do Spring Boot os dois primeiros falham, porque `BOOT-INF/classes/` é entrada de jar aninhado e não caminho de arquivo. A alternativa — montar o caminho com `SUBREPORT_DIR` — funciona na IDE e quebra no container, que é o pior modo de falha possível.

## Considered Options

- **Compilar em runtime a partir do `.jrxml` no classpath** — recusada. Exige o compilador JDT no runtime da API, paga centenas de milissegundos na primeira Geração de cada Relatório e adia para produção um erro que o CI pegaria de graça. O ganho seria publicar template sem release, e isso não existe enquanto o template vier do artefato (ADR-0022).
- **Versionar o `.jasper` já compilado no repositório** — recusada. Binário não é diffável nem revisável, e desacopla o template da versão da biblioteca que o produziu — o `.jasper` sobrevive a um upgrade do JasperReports sem que nada acuse a incompatibilidade até a Geração falhar.

## Consequências

- Um `.jasper` é objeto Java serializado, e carregá-lo é desserialização via `JRLoader` — o caminho de código do CVE-2025-10492 (filtro de classes na 7.0.4) e do CVE-2026-6009 (segundo filtro na 7.0.7). Aqui isso é aceitável porque o arquivo é produzido pelo próprio build e viaja dentro do artefato: é tão confiável quanto o bytecode ao lado dele. **O que sustenta essa confiança é a origem, não o formato.** Carregar `.jasper` de bucket, volume montado ou upload reabre o problema por inteiro — e é por isso que a API não deve ter caminho de carga de template fora do classpath.
- Subir a versão do JasperReports recompila o catálogo inteiro automaticamente. Não existe `.jasper` órfão de versão anterior, e nenhum Relatório descobre a incompatibilidade sozinho, em produção, na primeira Geração depois do upgrade.
- O compilador (JDT/ecj) passa a ser dependência de build, não de runtime: imagem menor e uma superfície a menos na JVM que atende a internet (ADR-0010).
- Os templates precisam ser carregados uma vez e mantidos em cache. `JRClassLoader` cria um ClassLoader novo a cada carga de classe de expressão, e cada um retém a classe gerada; sem cache, cada Geração acrescenta Metaspace que só volta com restart do container. Com catálogo estático e cache, o custo é limitado e pago uma vez por template.
- **O passo de compilação é a parte frágil.** O `org.codehaus.mojo:jasperreports-maven-plugin` está abandonado; o sucessor comunitário (`Jasper-report-maven-plugin`, de alexnederlof, hoje sob a organização pro-crafting) tem como objetivo declarado acompanhar a versão corrente da biblioteca, mas historicamente corre atrás dela. Se o plugin não suportar a JasperReports em uso, o fallback é invocar `JasperCompileManager` pela própria dependência do projeto num passo `exec` do build: mais verboso, sem plugin de terceiro e sem qualquer risco de divergência de versão.
- Um template quebrado bloqueia o release, que é único e conjunto (ADR-0001) — erro de layout em um Relatório impede a liberação de tudo. É o preço do fail-fast, e é o comportamento desejado: o inverso é descobrir o erro quando um Relator clica em baixar.
- O seam 1 precisa de pelo menos um `.jrxml` real em `api/src/test/resources/`, compilado pelo mesmo passo do build. Um fixture montado por outro caminho testaria algo que produção não faz.
