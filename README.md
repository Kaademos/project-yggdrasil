# Kademos Yggdrasil Monorepo (Bootstrap)

This repository hosts the secure control plane (`core/*`) and intentionally vulnerable realms (`realms/*`).  
Start by reading `.docs/security/secure_coding_handbook.md` and install hooks:

```bash
pipx install pre-commit || pip install pre-commit
pre-commit install
```

Run Semgrep locally:
```bash
semgrep --config config/semgrep.yml
```

Commit with template:
```bash
git config commit.template config/commit_template.txt
```