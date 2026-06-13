<!-- V1: Blazor Example + Docker Infrastructure -->

## Summary
<!-- What does this PR do? 1–3 bullet points. -->

## Related issue
<!-- Closes #<issue number> -->

## Type of change
- [ ] Bug fix
- [ ] New connector
- [ ] New feature
- [ ] Refactor
- [ ] Docs / infra
- [ ] Breaking change

## Test plan
- [ ] `dotnet test src/SqlSpaExplorer.sln` passes
- [ ] Proto stack runs: `docker compose -f docker/docker-compose.proto.yml up -d`
- [ ] App responds at `http://localhost:42080`
- [ ] For new connectors: integration test against containerised DB
