# Skill: github-workflows

Covers `.github/workflows/` CI/CD pipelines.

## Workflow Files

| File | Trigger | Purpose |
|---|---|---|
| `ci.yml` | Push / PR to `main` | Build, test (unit + bUnit), publish test results |
| `docker-build.yml` | Push to `main` + tags | Multi-arch Docker image build and push to GHCR |
| `docfx-pages.yml` | Push to `main` | Build DocFX site and deploy to GitHub Pages |
| `codeql.yml` | Push / PR + weekly schedule | GitHub CodeQL security scan |

## ci.yml Structure

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.x'
      - run: dotnet restore src/SqlSpaExplorer.sln
      - run: dotnet build src/SqlSpaExplorer.sln --no-restore -c Release
      - run: dotnet test src/SqlSpaExplorer.sln --no-build -c Release --logger trx
```

Integration tests (connector tests against live DBs) are **excluded** from CI — they require the Docker stack. Tag them with `[Trait("Category", "Integration")]` and filter with `--filter "Category!=Integration"`.

## docker-build.yml — Multi-Arch

Uses `docker/setup-qemu-action` + `docker/setup-buildx-action` to build `linux/amd64` and `linux/arm64` images and push both to GitHub Container Registry (`ghcr.io`):

```yaml
- uses: docker/build-push-action@v5
  with:
    context: .
    file: docker/Dockerfile
    platforms: linux/amd64,linux/arm64
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

## CODEOWNERS

`.github/CODEOWNERS` gates PRs on the `src/SqlSpaExplorer.Core/Abstractions/` path — any change to the `IDatabaseConnector` interface or `TabularResult` requires an explicit approval.

## Branch Protection

`main` requires: CI passing + CodeQL passing + at least one CODEOWNERS approval.
