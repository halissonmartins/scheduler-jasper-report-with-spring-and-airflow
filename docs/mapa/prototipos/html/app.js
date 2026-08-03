/* PROTÓTIPO DESCARTÁVEL — HTML/CSS/JS puros, sem backend.
   Telas: ?tela=disponiveis|sem-acesso|vinculacao|pendentes|erro
   Variantes (só em "disponiveis"): ?variant=A|B|C
   Setas ← → alternam a variante. */

const TELAS = [
  { id: 'disponiveis', rotulo: 'Relatórios disponíveis', variantes: ['A', 'B', 'C'] },
  { id: 'sem-acesso',  rotulo: 'Sem acesso',             variantes: null },
  { id: 'vinculacao',  rotulo: 'Roles × Grupos',         variantes: null },
  { id: 'pendentes',   rotulo: 'Fila de pendentes',      variantes: null },
  { id: 'erro',        rotulo: 'Mensagens de erro',      variantes: null },
];

const NOME_VARIANTE = {
  A: 'selects encadeados',
  B: 'árvore expansível',
  C: 'lista única com filtros',
};

const FORMATOS = ['PDF', 'XLSX', 'DOCX', 'CSV'];

const params = () => new URLSearchParams(location.search);
const telaAtual = () => params().get('tela') || 'disponiveis';
const varAtual = () => params().get('variant') || 'A';

function irPara(mudancas) {
  const p = params();
  Object.entries(mudancas).forEach(([k, v]) => v === null ? p.delete(k) : p.set(k, v));
  history.replaceState(null, '', '?' + p.toString());
  desenhar();
}

/* ---------------------------------------------------------------- helpers */

const el = (tag, attrs = {}, ...filhos) => {
  const n = document.createElement(tag);
  Object.entries(attrs).forEach(([k, v]) => {
    if (k === 'class') n.className = v;
    else if (k.startsWith('on')) n.addEventListener(k.slice(2), v);
    else if (v !== null && v !== false) n.setAttribute(k, v);
  });
  filhos.flat().forEach(f => n.append(f?.nodeType ? f : document.createTextNode(f ?? '')));
  return n;
};

const brDate = iso => iso.split('-').reverse().join('/');

/* Os três estados que se parecem na tela e significam coisas opostas. */
function seloDe(item) {
  if (!item.temDados) return el('span', { class: 'selo semdados', title: 'A coleta rodou e a origem não tinha registros.' }, 'sem dados');
  if (item.expirado)  return el('span', { class: 'selo expirado', title: 'Expurgado pela política de retenção.' }, 'expirado em ' + brDate(item.expurgoPrevisto));
  if (item.status === 'ALERTA') return el('span', { class: 'selo alerta', title: 'Passou do tempo estimado. O relatório está disponível.' }, 'disponível · lento');
  return el('span', { class: 'selo disponivel' }, 'disponível');
}

/* Regra do ticket 27: a marcação de expirado é conservadora — o botão NÃO é
   desabilitado por ela, no máximo avisa. Só "sem dados" bloqueia. */
function podeBaixar(item) { return item.temDados; }

function baixar(item, formato) {
  const url = `/api/relatorios/${item.codigo}/execucoes/${item.dataReferencia}/exportacao?formato=${formato}`;
  alert('GET ' + url + '\n\n(protótipo: nenhuma requisição é feita)');
}

function seletorFormato(item) {
  const sel = el('select', { 'aria-label': 'formato' }, ...FORMATOS.map(f => el('option', {}, f)));
  const btn = el('button', {
    disabled: !podeBaixar(item),
    onclick: () => baixar(item, sel.value),
  }, 'Baixar');
  const caixa = el('span', { class: 'linha-campos', style: 'gap:8px' }, sel, btn);
  if (!podeBaixar(item)) {
    sel.disabled = true;
    caixa.append(el('span', { class: 'sub', style: 'margin:0 0 0 8px' }, 'nada a baixar'));
  }
  return caixa;
}

/* =========================================================== TELA: disponíveis */

function telaDisponiveis(variante) {
  const raiz = el('div');
  raiz.append(
    el('h2', {}, 'Relatórios disponíveis'),
    el('p', { class: 'sub' },
      'Uma chamada só devolve as ' + DISPONIVEIS.length +
      ' execuções disponíveis; a navegação por data → produto → código acontece em memória, sem ir à rede.')
  );
  raiz.append(({ A: variantA, B: variantB, C: variantC })[variante]());
  return raiz;
}

/* ---- A: três selects encadeados. Espelha literalmente o documento. ---- */
function variantA() {
  const cartao = el('div', { class: 'cartao' });
  const datas = [...new Set(DISPONIVEIS.map(i => i.dataReferencia))].sort().reverse();

  const selData = el('select', {}, ...datas.map(d => el('option', { value: d }, brDate(d))));
  const selProd = el('select', {});
  const selRel  = el('select', {});
  const area    = el('div', { style: 'margin-top:18px' });

  function preencherProdutos() {
    const doDia = DISPONIVEIS.filter(i => i.dataReferencia === selData.value);
    const prods = [...new Map(doDia.map(i => [i.sigla, i.nomeProduto])).entries()];
    selProd.replaceChildren(...prods.map(([s, n]) => el('option', { value: s }, n)));
    preencherRelatorios();
  }
  function preencherRelatorios() {
    const lista = DISPONIVEIS.filter(i => i.dataReferencia === selData.value && i.sigla === selProd.value);
    selRel.replaceChildren(...lista.map(i => el('option', { value: i.codigo }, `${i.codigo} — ${i.nome}`)));
    mostrar();
  }
  function mostrar() {
    const item = DISPONIVEIS.find(i =>
      i.dataReferencia === selData.value && i.sigla === selProd.value && i.codigo === selRel.value);
    area.replaceChildren();
    if (!item) return;
    area.append(
      el('div', { class: 'linha-campos' },
        el('div', {}, el('strong', {}, item.codigo + ' — ' + item.nome), el('div', {}, seloDe(item))),
        el('div', { style: 'margin-left:auto' }, seletorFormato(item))
      )
    );
  }

  selData.addEventListener('change', preencherProdutos);
  selProd.addEventListener('change', preencherRelatorios);
  selRel.addEventListener('change', mostrar);

  cartao.append(
    el('div', { class: 'linha-campos' },
      el('div', {}, el('label', {}, 'Data de referência'), selData),
      el('div', {}, el('label', {}, 'Produto'), selProd),
      el('div', {}, el('label', {}, 'Relatório'), selRel),
    ),
    area
  );
  preencherProdutos();
  return cartao;
}

/* ---- B: árvore expansível. Mostra o caminho inteiro de uma vez. ---- */
function variantB() {
  const cartao = el('div', { class: 'cartao' });
  const datas = [...new Set(DISPONIVEIS.map(i => i.dataReferencia))].sort().reverse();

  const raizUl = el('ul', { class: 'arvore' });
  datas.forEach((d, idx) => {
    const doDia = DISPONIVEIS.filter(i => i.dataReferencia === d);
    const ulProd = el('ul', { hidden: idx !== 0 ? '' : null });
    const btnData = el('button', { class: 'no', 'aria-expanded': String(idx === 0),
      onclick: e => { const ex = e.target.getAttribute('aria-expanded') === 'true';
        e.target.setAttribute('aria-expanded', String(!ex)); ulProd.hidden = ex; } },
      `${brDate(d)}  (${doDia.length})`);

    const prods = [...new Map(doDia.map(i => [i.sigla, i.nomeProduto])).entries()];
    prods.forEach(([sigla, nomeProd]) => {
      const doProd = doDia.filter(i => i.sigla === sigla);
      const ulRel = el('ul', { hidden: '' });
      const btnProd = el('button', { class: 'no', 'aria-expanded': 'false',
        onclick: e => { const ex = e.target.getAttribute('aria-expanded') === 'true';
          e.target.setAttribute('aria-expanded', String(!ex)); ulRel.hidden = ex; } },
        `${nomeProd}  (${doProd.length})`);
      doProd.forEach(item => ulRel.append(el('li', {},
        el('div', { class: 'folha' },
          el('span', { class: 'nome-rel' }, `${item.codigo} — ${item.nome}`),
          seloDe(item), seletorFormato(item)))));
      ulProd.append(el('li', {}, btnProd, ulRel));
    });
    raizUl.append(el('li', {}, btnData, ulProd));
  });

  cartao.append(raizUl);
  return cartao;
}

/* ---- C: lista única com filtros. Abandona a hierarquia do documento. ---- */
function variantC() {
  const cartao = el('div', { class: 'cartao' });
  const datas = [...new Set(DISPONIVEIS.map(i => i.dataReferencia))].sort().reverse();
  const prods = [...new Map(DISPONIVEIS.map(i => [i.sigla, i.nomeProduto])).entries()];

  const fData = el('select', {}, el('option', { value: '' }, 'todas'), ...datas.map(d => el('option', { value: d }, brDate(d))));
  const fProd = el('select', {}, el('option', { value: '' }, 'todos'), ...prods.map(([s, n]) => el('option', { value: s }, n)));
  const fTexto = el('input', { type: 'text', placeholder: 'código ou nome' });
  const fOcultarMortos = el('input', { type: 'checkbox' });

  const corpo = el('tbody');
  function render() {
    const t = fTexto.value.trim().toLowerCase();
    const linhas = DISPONIVEIS.filter(i =>
      (!fData.value || i.dataReferencia === fData.value) &&
      (!fProd.value || i.sigla === fProd.value) &&
      (!t || i.codigo.toLowerCase().includes(t) || i.nome.toLowerCase().includes(t)) &&
      (!fOcultarMortos.checked || (i.temDados && !i.expirado))
    ).sort((a, b) => b.dataReferencia.localeCompare(a.dataReferencia) || a.codigo.localeCompare(b.codigo));

    corpo.replaceChildren(...linhas.map(i => el('tr', { class: (!i.temDados || i.expirado) ? 'morta' : '' },
      el('td', {}, brDate(i.dataReferencia)),
      el('td', {}, i.nomeProduto),
      el('td', {}, el('strong', {}, i.codigo), el('div', { class: 'sub', style: 'margin:0' }, i.nome)),
      el('td', {}, seloDe(i)),
      el('td', { class: 'acao' }, seletorFormato(i)),
    )));
    contagem.textContent = `${linhas.length} de ${DISPONIVEIS.length}`;
  }
  const contagem = el('span', { class: 'sub', style: 'margin:0 0 0 auto' });
  [fData, fProd, fOcultarMortos].forEach(c => c.addEventListener('change', render));
  fTexto.addEventListener('input', render);

  cartao.append(
    el('div', { class: 'linha-campos', style: 'margin-bottom:16px' },
      el('div', {}, el('label', {}, 'Data'), fData),
      el('div', {}, el('label', {}, 'Produto'), fProd),
      el('div', {}, el('label', {}, 'Busca'), fTexto),
      el('label', { style: 'display:flex;gap:6px;align-items:center;margin:0' }, fOcultarMortos, 'só o que dá para baixar'),
      contagem),
    el('table', {},
      el('thead', {}, el('tr', {},
        el('th', {}, 'Data'), el('th', {}, 'Produto'), el('th', {}, 'Relatório'),
        el('th', {}, 'Estado'), el('th', {}, 'Exportar'))),
      corpo)
  );
  render();
  return cartao;
}

/* ========================================================== TELA: sem acesso */

function telaSemAcesso() {
  return el('div', { class: 'cartao vazio' },
    el('h3', {}, 'Seu acesso ainda não foi configurado'),
    el('p', {}, 'Procure seu gerente para ser vinculado a um grupo de relatórios.'),
    el('p', { class: 'sub', style: 'margin-top:24px' },
      'A API devolve lista vazia — e ela não distingue "aguardando vínculo" de ' +
      '"vinculado a um grupo que ainda não libera nada". Por isso a tela é uma só.')
  );
}

/* ========================================================== TELA: vinculação */

function telaVinculacao() {
  const raiz = el('div');
  let grupoSel = GRUPOS[0];
  let selEsq = null, selDir = null;

  const painelDisp = el('div', { class: 'painel' });
  const painelVinc = el('div', { class: 'painel' });
  const btnAdd = el('button', { class: 'secundario', onclick: () => mover(true) }, '→');
  const btnDel = el('button', { class: 'secundario', onclick: () => mover(false) }, '←');

  const selGrupo = el('select', {}, ...GRUPOS.map(g => el('option', { value: g.id }, g.nome)));
  selGrupo.addEventListener('change', () => {
    grupoSel = GRUPOS.find(g => g.id === selGrupo.value); selEsq = selDir = null; render();
  });

  function mover(paraDireita) {
    if (paraDireita && selEsq) grupoSel.roles.push(selEsq);
    if (!paraDireita && selDir) grupoSel.roles = grupoSel.roles.filter(r => r !== selDir);
    selEsq = selDir = null; render();
  }

  function render() {
    const vinculadas = grupoSel.roles;
    const disponiveis = ROLES.map(r => r.nome).filter(n => !vinculadas.includes(n));

    painelDisp.replaceChildren(el('h4', {}, `Roles de Relatório (${disponiveis.length})`),
      ...disponiveis.map(n => el('div', {
        class: 'item', 'aria-selected': String(selEsq === n),
        onclick: () => { selEsq = n; selDir = null; render(); }
      }, n)));

    painelVinc.replaceChildren(el('h4', {}, `Vinculadas a "${grupoSel.nome}" (${vinculadas.length})`),
      ...vinculadas.map(n => el('div', {
        class: 'item', 'aria-selected': String(selDir === n),
        onclick: () => { selDir = n; selEsq = null; render(); }
      }, n)));

    btnAdd.disabled = !selEsq;
    btnDel.disabled = !selDir;
  }

  raiz.append(
    el('h2', {}, 'Roles de Relatório × Grupos'),
    el('p', { class: 'sub' },
      'Sete roles e quatro grupos é a escala real deste sistema — dois painéis com transferência ' +
      'cabem folgadamente. A questão que o protótipo levanta é se isso ainda serve com dez vezes mais.'),
    el('div', { class: 'cartao' },
      el('div', { class: 'linha-campos', style: 'margin-bottom:16px' },
        el('div', {}, el('label', {}, 'Grupo'), selGrupo)),
      el('div', { class: 'dois-paineis' },
        painelDisp,
        el('div', { class: 'setas' }, btnAdd, btnDel),
        painelVinc))
  );
  render();
  return raiz;
}

/* =========================================================== TELA: pendentes */

function telaPendentes() {
  const raiz = el('div');
  const lista = [...PENDENTES].sort((a, b) => b.diasAguardando - a.diasAguardando);
  const corpo = el('tbody');

  function render() {
    corpo.replaceChildren(...lista.map(u => el('tr', {},
      el('td', {}, el('strong', {}, u.username), el('div', { class: 'sub', style: 'margin:0' }, u.email)),
      el('td', { class: 'idade' + (u.diasAguardando > 30 ? ' velha' : '') }, `${u.diasAguardando} dias`),
      el('td', { class: 'acao' },
        el('div', { class: 'linha-campos', style: 'gap:8px' },
          el('select', { 'aria-label': 'grupo' }, ...GRUPOS.map(g => el('option', {}, g.nome))),
          el('button', {
            onclick: () => alert(
              'Vincular ao grupo\n\n' +
              'Um gesto na tela, duas chamadas por baixo:\n' +
              '  PUT  /grupos/{id}/membros\n' +
              '  DELETE do PENDENTES\n\n' +
              'Se a segunda falhar → 500 VINCULACAO_INCOMPLETA.\n' +
              'O gerente precisa saber, não receber sucesso silencioso.')
          }, 'Vincular')))
    )));
  }

  raiz.append(
    el('h2', {}, 'Cadastros aguardando vínculo'),
    el('p', { class: 'sub' },
      'Esta lista é o único aviso que existe — não há e-mail. Ordenada pelos mais antigos, ' +
      'e quem passa de 30 dias fica destacado. Só aparecem cadastros com e-mail verificado.'),
    el('div', { class: 'cartao' },
      el('table', {},
        el('thead', {}, el('tr', {}, el('th', {}, 'Usuário'), el('th', {}, 'Aguardando'), el('th', {}, 'Vincular'))),
        corpo))
  );
  render();
  return raiz;
}

/* =============================================================== TELA: erros */

function caixaErro(chave) {
  const e = ERROS[chave];
  const caixa = el('div', { class: 'erro-caixa ' + (e.permanente ? 'permanente' : 'transitorio') });

  caixa.append(
    el('h3', {}, e.corpo.title),
    el('div', {}, e.corpo.detail),
    el('div', { class: 'meta' },
      'Ocorrido em ', el('code', {}, new Date(e.corpo.momento).toLocaleString('pt-BR')),
      ' · Correlation ID ', el('span', { class: 'corr' }, e.corpo.correlationId))
  );

  const acoes = el('div', { class: 'linha-campos', style: 'gap:8px' });

  /* A diferença que o protótipo existe para testar. */
  if (e.permanente) {
    acoes.append(el('span', { class: 'sub', style: 'margin:0' },
      'Tentar de novo não resolve. Procure o administrador do relatório.'));
  } else if (e.refazerLogin) {
    acoes.append(el('button', {}, 'Entrar novamente'));
    acoes.append(el('span', { class: 'sub', style: 'margin:0' },
      'Seu acesso pode ter mudado há pouco. Refazer o login resolve esse caso.'));
  } else {
    acoes.append(el('button', {}, `Tentar de novo (${e.retryAfter}s)`));
    acoes.append(el('span', { class: 'sub', style: 'margin:0' }, 'É temporário — o sistema está ocupado.'));
  }

  const json = JSON.stringify(e.corpo, null, 2);
  const btnCopiar = el('button', { class: 'secundario', onclick: () => {
    navigator.clipboard?.writeText(json);
    btnCopiar.textContent = 'copiado';
    setTimeout(() => btnCopiar.textContent = 'Copiar JSON', 1400);
  } }, 'Copiar JSON');
  acoes.append(btnCopiar);

  caixa.append(acoes, el('pre', { class: 'json' }, json));
  return caixa;
}

function telaErro() {
  return el('div', {},
    el('h2', {}, 'Mensagens de erro'),
    el('p', { class: 'sub' },
      'O corpo já é o JSON do contrato (RFC 9457), então "copiar em JSON" copia a resposta verbatim. ' +
      'Os dois primeiros são opostos: um é permanente e não deve convidar a repetir; o outro é transitório e deve.'),
    ...Object.keys(ERROS).map(k => el('div', { class: 'cartao' },
      el('p', { class: 'sub', style: 'margin:0 0 12px' }, ERROS[k].rotulo),
      caixaErro(k)))
  );
}

/* ============================================================== composição */

function barra() {
  const tela = telaAtual();
  const def = TELAS.find(t => t.id === tela);
  const temVar = !!def?.variantes;
  const v = varAtual();

  const selTela = el('select', {
    onchange: e => irPara({ tela: e.target.value, variant: null })
  }, ...TELAS.map(t => el('option', { value: t.id, selected: t.id === tela ? '' : null }, t.rotulo)));

  const rotulo = el('span', { class: 'rotulo' + (temVar ? '' : ' apagado') },
    temVar ? `${v} — ${NOME_VARIANTE[v]}` : 'sem variantes');

  const ciclar = passo => {
    if (!temVar) return;
    const i = def.variantes.indexOf(v);
    irPara({ variant: def.variantes[(i + passo + def.variantes.length) % def.variantes.length] });
  };

  return el('div', { class: 'barra' },
    el('span', { class: 'marca' }, 'protótipo'),
    selTela,
    el('button', { onclick: () => ciclar(-1), disabled: !temVar, 'aria-label': 'variante anterior' }, '‹'),
    rotulo,
    el('button', { onclick: () => ciclar(1), disabled: !temVar, 'aria-label': 'próxima variante' }, '›'),
  );
}

function desenhar() {
  const tela = telaAtual();
  const main = document.querySelector('main');
  main.replaceChildren(({
    'disponiveis': () => telaDisponiveis(varAtual()),
    'sem-acesso': telaSemAcesso,
    'vinculacao': telaVinculacao,
    'pendentes': telaPendentes,
    'erro': telaErro,
  }[tela] || (() => telaDisponiveis('A')))());

  document.querySelector('.barra')?.remove();
  document.body.append(barra());

  const c = document.querySelector('.contador');
  if (c) c.textContent = PENDENTES.length;
}

document.addEventListener('keydown', e => {
  if (/^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName) || e.target.isContentEditable) return;
  if (e.key === 'ArrowLeft')  document.querySelectorAll('.barra button')[0]?.click();
  if (e.key === 'ArrowRight') document.querySelectorAll('.barra button')[1]?.click();
});

desenhar();
