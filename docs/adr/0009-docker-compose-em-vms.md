# Docker Compose em VMs como alvo de produção

Produção roda Docker Compose em VMs. O Airflow lança cada processador com `DockerOperator`.

Escolhido pela simplicidade operacional e por corresponder ao que a equipe já opera; Kubernetes foi recomendado e recusado.

## Consequências (riscos aceitos)

- Não há deploy sem downtime: reiniciar é parar.
- Um único container de API torna o risco de OOM do ADR-0004 mais agudo — não há réplica para absorver a queda.
- O replica set do MongoDB, seus backups e o teste de restauração são inteiramente artesanais.
- O `DockerOperator` exige o socket do Docker montado no Airflow. Comprometer o Airflow equivale, portanto, a root na máquina. Por isso ficou decidido que **a interface do Airflow não é publicada na internet**: o webserver escuta apenas na rede interna (ou em 127.0.0.1, com acesso por túnel SSH/VPN) e não recebe regra de ingress. É a exceção deliberada ao ADR-0010 — expor um painel que dispara containers com o socket montado é execução remota de código, não uma tela de consulta.
