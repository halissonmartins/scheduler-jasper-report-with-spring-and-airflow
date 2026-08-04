# 28 — Angular: telas do GERENTE

**O que construir:** a superfície onde o acesso é concedido. A fila de pendentes é a **única** tela
que revela quem está esperando — não há e-mail de aviso em lugar nenhum do sistema, então essa tela é
o mecanismo, não uma conveniência.

**Bloqueado por:** 21, 27.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Contador de cadastros aguardando vínculo visível na entrada.
- [ ] Fila de pendentes com há quanto tempo cada um espera, ordenada pelos mais antigos — o que torna
      a limpeza uma decisão informada e humana, já que nada expira sozinho e a exclusão é definitiva.
- [ ] Vinculação de RELATOR a Grupo, com a recusa de vincular a Grupo sem Role exibida de forma
      compreensível.
- [ ] Gestão de Grupos e das Roles de Relatório vinculadas a eles.
- [ ] Usuários da alçada, consultando o estado real do provedor ao vivo — é o que distingue
      "aguardando vínculo" de "vinculado sem Relatório", que a API deliberadamente **não** distingue.
- [ ] A vinculação incompleta aparece como tal, não como sucesso.
