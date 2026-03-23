# OpenCode config rollback snapshot

- Live source: `/home/glom/.config/opencode/opencode.json`
- Snapshot date: 2026-03-24
- SHA-256 of full live file: `24f9a8cd52aa00900633b13dc9cedb60a42e7b64118cacaf97572be35928ea6d`
- Secret handling: `provider.openai.options.apiKey` is intentionally redacted here and must not be copied into tracked repo files
- Purpose: preserve rollback/equivalence evidence without leaking the live credential

```json
{
  "plugin": [
    "oh-my-opencode@latest"
  ],
  "provider": {
    "openai": {
      "options": {
        "baseURL": "http://0.0.0.0:8080/v1",
        "apiKey": "<redacted-live-secret>"
      },
      "models": {
        "gpt-5-codex": {
          "name": "GPT-5 Codex",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {}
          }
        },
        "gpt-5.1-codex": {
          "name": "GPT-5.1 Codex",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {}
          }
        },
        "gpt-5.1-codex-max": {
          "name": "GPT-5.1 Codex Max",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {}
          }
        },
        "gpt-5.1-codex-mini": {
          "name": "GPT-5.1 Codex Mini",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {}
          }
        },
        "gpt-5.2": {
          "name": "GPT-5.2",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {},
            "xhigh": {}
          }
        },
        "gpt-5.4": {
          "name": "GPT-5.4",
          "limit": {
            "context": 1050000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {},
            "xhigh": {}
          }
        },
        "gpt-5.3-codex-spark": {
          "name": "GPT-5.3 Codex Spark",
          "limit": {
            "context": 128000,
            "output": 32000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {},
            "xhigh": {}
          }
        },
        "gpt-5.3-codex": {
          "name": "GPT-5.3 Codex",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {},
            "xhigh": {}
          }
        },
        "gpt-5.2-codex": {
          "name": "GPT-5.2 Codex",
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {},
            "xhigh": {}
          }
        },
        "codex-mini-latest": {
          "name": "Codex Mini",
          "limit": {
            "context": 200000,
            "output": 100000
          },
          "options": {
            "store": false
          },
          "variants": {
            "low": {},
            "medium": {},
            "high": {}
          }
        }
      }
    }
  },
  "agent": {
    "build": {
      "options": {
        "store": false
      }
    },
    "plan": {
      "options": {
        "store": false
      }
    }
  },
  "$schema": "https://opencode.ai/config.json"
}
```
