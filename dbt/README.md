# dbt Models — EV Pipeline

## Design Decision: dbt vs Dynamic Tables

This project primarily uses **Dynamic Tables** for transformations because:
- All transforms are pure SQL with predictable refresh patterns
- Declarative (no orchestration code)
- Auto-dependency resolution
- Fewer moving parts for a small pipeline

This dbt model (`agg_yoy_adoption_growth`) demonstrates **when dbt adds value**:

| Capability | Dynamic Tables | dbt |
|-----------|---------------|-----|
| Dependency management | Automatic (DT knows its upstream) | `ref()` macro |
| Data testing | Manual SQL assertions | Built-in (`unique`, `not_null`, `accepted_values`) |
| Documentation | Manual | Auto-generated lineage + docs site |
| Version control | SQL files in git | Same + compilation + dry-run |
| CI/CD | SchemaChange or snowflake-cli | `dbt build` in GitHub Actions |
| Incremental loads | Not needed (DT handles it) | `materialized='incremental'` |

## When to Use dbt Over Dynamic Tables

- 100+ models with cross-team ownership
- Need CI/CD-driven testing before promotion
- Want auto-generated data documentation
- Multiple environments (dev/staging/prod) with promotion workflow
- Complex incremental logic with merge strategies

## Running This Model

```bash
# Set environment variables
export SNOWFLAKE_ACCOUNT=<your_account>
export SNOWFLAKE_USER=<your_user>
export SNOWFLAKE_PASSWORD=<your_password>

# Run
dbt run --models agg_yoy_adoption_growth
dbt test --models agg_yoy_adoption_growth
```

## Running in Snowsight (Native dbt)

This model can also be run directly from **Snowsight → Transformation → dbt Projects** without any local setup.
