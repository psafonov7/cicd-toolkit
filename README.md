# cicd-toolkit

Коллекция билд-скриптов с тонкими врапперами для нескольких CI-систем. Ядро
каждого компонента — обычный bash-скрипт, который можно редактировать,
валидировать (`shellcheck`/`shfmt`) и запускать локально. Поверх него — по
одному врапперу на CI-систему: `action.yml` для GitHub Actions и
`component.yml` для GitLab CI.

## Принципы

- **Единый источник истины** — вся логика в `*.sh`, врапперы только маппят
  inputs → env-переменные.
- **Нулевые зависимости** — только bash и инструменты самого компонента.
- **Локальный прогон** — каждый компонент тестируется через [`act`](https://github.com/nektos/act).
- **Параметризация через env** — скрипты работают и standalone, и через врапперы.

## Компоненты

| Компонент | Назначение |
|---|---|
| [`docker/`](docker/) | Сборка и push multi-arch Docker-образа через buildx |
| [`go/`](go/) | Линт, тесты и сборка Go-бинаря (gofmt, go vet, golangci-lint, go test, govulncheck, gosec) |
| [`helm/`](helm/) | Линт и упаковка Helm-чарта |
| [`python/setup/`](python/setup/) | Установка Python (pip/uv) |
| [`build-info/`](build-info/) | Сбор метаданных сборки |
| [`sha-short/`](sha-short/) | Короткий SHA коммита |
| [`github/get_latest_version/`](github/get_latest_version/) | Последний стабильный релиз репозитория |
| [`notify/telegram/`](notify/telegram/) | Уведомления в Telegram |
| [`shared/`](shared/) | Общие утилиты (`utils.sh`, `get_checksum.sh`, `get_latest_version.sh`) |

## Подключение в проект

Рекомендуемый способ — git submodule:

```bash
git submodule add <cicd-toolkit-url> cicd-toolkit
```

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - uses: actions/setup-go@v5
        with:
          go-version: '1.26'

      - name: Validate and build Go binary
        uses: ./cicd-toolkit/go
        with:
          version: ${{ github.ref_name }}

      - name: Build and push Docker image
        uses: ./cicd-toolkit/docker
        with:
          build_number: ${{ github.ref_name }}
          push: true
          registry_username: ${{ vars.REGISTRY_USERNAME }}
          registry_token: ${{ secrets.REGISTRY_TOKEN }}
```

### GitLab CI

```yaml
include:
  - component: $CI_SERVER_FORTH/components/cicd-toolkit/go@main
    inputs:
      version: $CI_COMMIT_TAG

  - component: $CI_SERVER_FORTH/components/cicd-toolkit/docker@main
    inputs:
      build_number: $CI_COMMIT_TAG
      push: true

variables:
  GIT_SUBMODULE_STRATEGY: recursive
```

> Компоненты `go/` и `docker/` независимы: первый отвечает за код и бинарь,
> второй — за образ. Композируйте их в одном pipeline.

## Локальная проверка компонента

Каждый компонент содержит `tests/run_test.sh`, прогоняющий workflow через
`act`:

```bash
act -P ubuntu-latest=golang:1.26 -W go/tests/workflow_test.yml
```
