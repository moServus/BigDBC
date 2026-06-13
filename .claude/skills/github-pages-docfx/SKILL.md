# Skill: github-pages-docfx

Covers the documentation site built with DocFX and published to GitHub Pages.

## DocFX Setup

DocFX is installed as a .NET global tool:

```bash
dotnet tool install -g docfx
```

Config lives at `docs/docfx.json`. Two content sources:
1. **API docs** — generated from XML doc comments in `src/` (set `<GenerateDocumentationFile>true</GenerateDocumentationFile>` in each `.csproj`).
2. **Architecture docs** — hand-written Markdown in `docs/articles/`.

## Local Build & Preview

```bash
docfx docs/docfx.json --serve
# opens http://localhost:8080
```

## docfx.json Key Sections

```json
{
  "metadata": [{ "src": [{ "src": "../src", "files": ["**/*.csproj"] }], "dest": "api" }],
  "build": {
    "content": [
      { "files": ["api/**.yml", "api/index.md"] },
      { "files": ["articles/**.md", "toc.yml", "index.md"] }
    ],
    "dest": "_site",
    "globalMetadata": { "_appTitle": "SQL SPA Explorer" }
  }
}
```

## GitHub Pages Deployment (`docfx-pages.yml`)

```yaml
- run: dotnet tool install -g docfx
- run: docfx docs/docfx.json
- uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: docs/_site
```

Pages are served from the `gh-pages` branch. The workflow runs on every push to `main`.

## Writing Architecture Docs

Add Markdown files under `docs/articles/` and register them in `docs/articles/toc.yml`:

```yaml
- name: Architecture
  href: architecture.md
- name: Adding a Connector
  href: adding-connector.md
```

XML doc comments on public types in `Core/Abstractions/` are the primary API reference — keep them current when changing interface signatures.
