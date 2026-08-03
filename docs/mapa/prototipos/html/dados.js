/* PROTÓTIPO DESCARTÁVEL — dados de mentira.
   A forma segue o schema ExecucaoDisponivel de prototipos/openapi-descartavel.yaml. */

const PRODUTOS = [
  { sigla: 'POUPANCA',     nome: 'Poupança' },
  { sigla: 'CLIENTE',      nome: 'Cliente' },
  { sigla: 'CONTACORRENTE', nome: 'Conta Corrente' },
  { sigla: 'CONSORCIO',    nome: 'Consórcio' },
  { sigla: 'EMPRESTIMO',   nome: 'Empréstimo' },
];

const NOMES = {
  POUPANCA:      ['Saldos por agência', 'Rendimentos do período'],
  CLIENTE:       ['Cadastro por segmento', 'Clientes sem movimentação'],
  CONTACORRENTE: ['Extrato consolidado', 'Limites e utilização'],
  CONSORCIO:     ['Grupos ativos', 'Contemplações do mês'],
  EMPRESTIMO:    ['Carteira por faixa', 'Inadimplência'],
};

/* Dez datas, de propósito: a retenção é de 7 dias, então as mais antigas já tiveram
   os Artefatos expurgados — mas os metadados da Execução sobrevivem a eles e continuam
   listados. É assim que o estado "expirado" existe na tela. */
const DATAS = ['2026-07-24','2026-07-25','2026-07-26','2026-07-27','2026-07-28',
               '2026-07-29','2026-07-30','2026-07-31','2026-08-01','2026-08-02'];

/* A data de expurgo é a criação + 7 dias, arredondada para a meia-noite UTC seguinte.
   Como a Data de Referência é America/Sao_Paulo, o expurgo cai no dia anterior em BRT.
   Por isso a UI mostra a DATA REAL e nunca promete "7 dias". */
function expurgoDe(data) {
  const d = new Date(data + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + 7);
  return d.toISOString().slice(0, 10);
}

const HOJE = '2026-08-02';

function montarDisponiveis() {
  const itens = [];
  DATAS.forEach((data, di) => {
    PRODUTOS.forEach((p, pi) => {
      NOMES[p.sigla].forEach((nome, ni) => {
        const seq = String(ni + 1).padStart(4, '0');
        const codigo = `${p.sigla}-${seq}`;

        /* Distribuição pensada para o protótipo mostrar os três estados
           lado a lado, e não para ser realista. */
        let status = 'SUCESSO';
        let temDados = true;
        if (di === 8 && pi === 1 && ni === 1) { status = 'SEM_DADOS'; temDados = false; }
        if (di === 9 && pi === 3 && ni === 0) { status = 'SEM_DADOS'; temDados = false; }
        if (di === 1 && pi === 2 && ni === 0) { status = 'SEM_DADOS'; temDados = false; }
        if (di === 7 && pi === 0 && ni === 1) { status = 'ALERTA'; }
        if (di === 9 && pi === 4 && ni === 1) { status = 'ALERTA'; }
        if (di === 2 && pi === 0 && ni === 0) { status = 'ALERTA'; }
        /* Uma data sem nenhum relatório de um produto — para ver se a UI some
           com o nível ou mostra vazio. */
        if (di === 5 && pi === 2) return;

        const expurgo = expurgoDe(data);
        itens.push({
          codigo,
          nome,
          sigla: p.sigla,
          nomeProduto: p.nome,
          dataReferencia: data,
          status,
          temDados,
          expirado: expurgo <= HOJE,
          expurgoPrevisto: expurgo,
        });
      });
    });
  });
  return itens;
}

const DISPONIVEIS = montarDisponiveis();

/* ------------------------------------------------------- vinculação */

const ROLES = [
  { nome: 'REL_POUPANCA_GERENCIAL',    sigla: 'POUPANCA' },
  { nome: 'REL_POUPANCA_OPERACIONAL',  sigla: 'POUPANCA' },
  { nome: 'REL_CLIENTE_CADASTRO',      sigla: 'CLIENTE' },
  { nome: 'REL_CONTACORRENTE_EXTRATO', sigla: 'CONTACORRENTE' },
  { nome: 'REL_CONSORCIO_GRUPOS',      sigla: 'CONSORCIO' },
  { nome: 'REL_EMPRESTIMO_CARTEIRA',   sigla: 'EMPRESTIMO' },
  { nome: 'REL_EMPRESTIMO_RISCO',      sigla: 'EMPRESTIMO' },
];

const GRUPOS = [
  { id: 'g1', nome: 'Operação Poupança',  roles: ['REL_POUPANCA_OPERACIONAL'] },
  { id: 'g2', nome: 'Gerência Regional',  roles: ['REL_POUPANCA_GERENCIAL', 'REL_EMPRESTIMO_CARTEIRA'] },
  { id: 'g3', nome: 'Atendimento',        roles: [] },
  { id: 'g4', nome: 'Risco de Crédito',   roles: ['REL_EMPRESTIMO_RISCO'] },
];

/* Idades bem espalhadas de propósito: revela se a ordenação e o destaque funcionam. */
const PENDENTES = [
  { sub: 'u-901', username: 'marina.alves',  email: 'marina.alves@exemplo.com.br',  diasAguardando: 94 },
  { sub: 'u-902', username: 'joao.pereira',  email: 'joao.pereira@exemplo.com.br',  diasAguardando: 31 },
  { sub: 'u-903', username: 'lucia.ferraz',  email: 'lucia.ferraz@parceiro.com',    diasAguardando: 12 },
  { sub: 'u-904', username: 'rafael.gomes',  email: 'rafael.gomes@exemplo.com.br',  diasAguardando: 2 },
];

/* -------------------------------------------------------- erros RFC 9457 */

const ERROS = {
  acimaDoLimite: {
    rotulo: '409 — Artefato acima do limite',
    permanente: true,
    corpo: {
      type: 'urn:relatorios:erro:artefato-acima-do-limite',
      title: 'Artefato acima do limite',
      status: 409,
      detail: 'Este relatório excede o tamanho máximo para exportação.',
      instance: '/relatorios/EMPRESTIMO-0001/execucoes/2026-08-01/exportacao',
      codigo: 'ARTEFATO_ACIMA_DO_LIMITE',
      momento: '2026-08-02T14:31:09Z',
      correlationId: '4bf92f3577b34da6a3ce929d0e0e4736',
    },
  },
  indisponivel: {
    rotulo: '503 — Exportação indisponível',
    permanente: false,
    retryAfter: 20,
    corpo: {
      type: 'urn:relatorios:erro:exportacao-indisponivel',
      title: 'Exportação indisponível',
      status: 503,
      detail: 'Há muitas exportações em andamento no momento.',
      instance: '/relatorios/POUPANCA-0001/execucoes/2026-08-01/exportacao',
      codigo: 'EXPORTACAO_INDISPONIVEL',
      momento: '2026-08-02T14:33:41Z',
      correlationId: '9a1d0c2e8b7f4a35b6c0d9e8f7a61234',
    },
  },
  semPermissao: {
    rotulo: '403 — Sem permissão',
    permanente: false,
    refazerLogin: true,
    corpo: {
      type: 'urn:relatorios:erro:sem-permissao-para-relatorio',
      title: 'Sem permissão',
      status: 403,
      detail: 'Você não tem acesso a este relatório.',
      instance: '/relatorios/CONSORCIO-0002/execucoes/2026-08-01/exportacao',
      codigo: 'SEM_PERMISSAO_PARA_RELATORIO',
      momento: '2026-08-02T14:35:02Z',
      correlationId: 'c3e5a7b90d1f24689abc0de1f2345678',
    },
  },
};
