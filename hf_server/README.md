---
title: AIShoppingAssistance Server
emoji: 🔥
colorFrom: indigo
colorTo: green
sdk: docker
pinned: false
---

Check out the configuration reference at https://huggingface.co/docs/hub/spaces-config-reference

## Current Directory Structure for the Server
```
hf_server/
├── app/
│   ├── __init__.py              # Python package marker
│   ├── main.py                  # Main entrypoint (FastAPI, Middlewares, Routers, and lifespans)
│   ├── config.py                # Server & model configuration constants
│   ├── models/                  # Pydantic schemas / request-response models
│   │   ├── __init__.py
│   │   └── recipe.py            # Pydantic model for recipes
│   ├── services/                # Heavy logic & external database clients
│   │   ├── __init__.py
│   │   ├── http_client.py       # Global HTTPX AsyncClient lifecycle
│   │   ├── detector.py          # CLIP/ONNX model and embedding generation
│   │   ├── chroma.py            # ChromaDB Searcher
│   │   └── supabase.py          # Supabase Querier
│   ├── routes/                  # API endpoints
│   │   ├── __init__.py
│   │   ├── health.py            # health and root paths
│   │   ├── detection.py         # product detection, embeddings, and gallery
│   │   └── recipe.py            # recipe generation agent
│   └── agents/                  # AI agents & parser logic
│       ├── __init__.py
│       ├── recipe_agent.py      # Recipe agent orchestrator
│       ├── recipe_parser.py     # Markdown parser
│       └── tools/               # Agent tools
│           ├── __init__.py
│           ├── recipe_tool.py   # MealDB query tool
│           └── firecrawl_recipe_tool.py # Firecrawl scraping tool
├── requirements.txt
├── Dockerfile                  # Updated entrypoint cmd
└── run_local.sh
```
<!-- trigger -->