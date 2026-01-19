type: entry
id: t7vh4
location: unsaved
profile: general
provider: perplexity
model: sonar
query: test another query
title: Testing Custom Queries in CodeQL, SQL, and Testing Library
scope: repository
path: /home/cp/code/dkmaker/my-claude-plugins/knowledge/skills/research/lib
created: 2026-01-19T14:49:56.672Z
content: |
  Testing custom queries is supported in tools like **CodeQL** for static analysis, SQL-based systems, and frontend testing libraries.[1][2][3]
  
  In **CodeQL**, create a query (e.g., detecting empty `then` blocks in Java), add test code in a `tests` subdirectory with a `.qlref` file, then run `codeql test run java/tests/EmptyThen` to extract a database and verify results.[1]
  
  For **query-based tests** in IBM tools, define tests via the Assessment Builder: enter a test name, select datasource and schema, provide SQL statements for main logic and optional details, and set pass/fail result texts.[2]
  
  **Testing Library** offers query types like `getBy...` (throws on 0 or >1 matches), `queryBy...` (returns null on no match), and `findBy...` (async promise).[3]
  
  SQL examples include basic SELECT, WHERE, LIKE, and test data generation via CTEs with UNION ALL.[4][5]
examples: 3 hidden (use: research drafts show t7vh4 --examples)
sources: 7 hidden (use: research drafts show t7vh4 --sources)
