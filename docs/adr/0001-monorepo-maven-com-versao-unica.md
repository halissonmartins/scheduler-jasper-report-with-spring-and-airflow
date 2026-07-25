# Monorepo Maven com versão única

Todo o backend vive em um único agregador Maven na raiz (`common` → `processor-starter` → `processor-<produto>` × N → `api`), com uma versão compartilhada e liberação conjunta. `frontend/`, `airflow/` e `deploy/` são diretórios irmãos fora do reator.

Escolhido porque os módulos resolvem entre si pelo próprio reator — não é preciso operar um Nexus/Artifactory — e porque refatorações que atravessam o starter e os processadores permanecem atômicas em um único commit. O alvo de implantação (Docker Compose, ADR-0009) reinicia o conjunto de qualquer forma, então versionar módulos independentemente não compraria nada.

## Consequências

- Uma mudança no `processor-starter` reconstrói e reimplanta todos os processadores. Não há como um processador ficar em uma versão anterior do starter.
