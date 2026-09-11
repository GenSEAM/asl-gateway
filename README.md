# asl-gateway

Sovereign L7 Cognitive Gateway for AgentScript: Hierarchical LMK (LLM Models & Keys) Nexus, Tri-Channel Demuxing, Quarantined CoT Reasoning, and Pure ASN Wire Protocol Negotiation.

---

## 1. Overview & Architectural Role

The ASL Cognitive Gateway is the single point of entry (nexus) for all LLM inference in the AgentScript ecosystem. Whether requests originate from Addie (`gsa`), the Terminal UI (`terminal.ui`), in-browser agents (`agent-browser`), or external IDE agents (`asl-lens`), all traffic routes through the gateway at `http://127.0.0.1:8765/v1`.

The gateway decouples client agents from raw secrets and provider specifics while enforcing cognitive safety invariants:
- **Tri-Channel Demuxing**:
  - **Channel A**: Clean conversational text and declarative ASN structures (`:struct`, `:ast`, `:config`) for user interfaces.
  - **Channel B**: Quarantined internal reasoning (`<think>...</think>`) scratchpad tokens, isolated from user streams.
  - **Channel C**: Imperative tool execution frames (`(:call :tool ...)`), validated and forwarded to runtime tools.
- **Verbal ESH Interception**: Verbal claims of test execution or gate passage without verified runtime receipts are blocked before reaching user channels.

---

## 2. Hierarchical LMK (LLM Models & Keys) Cascade

Credentials and model profiles resolve deterministically through a 5-tier priority hierarchy:

1. **Dynamic Runtime / UI Overrides** (Highest Priority):
   Headers or request parameters passed directly from user interfaces or agent dynamic settings.
2. **Local Workspace Configuration**:
   Local `.asl/gateway.asn` or `.asl.config.asn` scoped to current workspace.
3. **Global User Configuration**:
   Global `~/.asl/gateway.asn` in user home directory.
4. **Process Environment Variables**:
   System variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OLLAMA_HOST`).
5. **Universal Default Fallback**:
   Local sovereign daemon endpoint (`http://127.0.0.1:8765/v1`, default model `gemma-4-31b-it`).

All secrets are masked (`sk-...xxxx`) when exposed in UI queries or telemetry records.

---

## 3. Pure ASN Wire Protocol

The gateway negotiates compact S-expression payloads over HTTP:

### Negotiation Headers
```http
X-ASL-Wire-Protocol: asn/1.0
X-Tool-Call-Dialect: asn-sexpr
Accept: application/asn+sexpr, application/json
```

### Disambiguation Mechanics
- **Imperative Tool Calls**:
  Expressions matching `(:call :tool "<name>" ...)` or `(call :tool "<name>" ...)` are routed exclusively to Channel C (execution).
- **Declarative ASN Data**:
  Expressions starting with `(:struct ...)`, `(:ast ...)`, `(:code ...)`, `(:config ...)`, `(:grammar ...)`, or `(module ...)` represent structural source code or specifications and remain preserved in Channel A (UI/text).

---

## 4. Module Map

- `manifest.asn`: Standalone package manifest.
- `grammar.asn`: Exported symbol registry.
- `src/lmk.asl`: LMK hierarchy resolution and secret masking.
- `src/wire.asl`: Protocol headers and imperative vs declarative ASN disambiguation.
- `src/server.asl`: L7 inspection pipeline, tri-channel demuxer, and verbal ESH interception.
- `tests/lmk-test.asl`: Verification of 5-tier resolution priority.
- `tests/wire-test.asl`: Verification of wire headers and tool disambiguation.
- `tests/server-test.asl`: Verification of CoT quarantine and ESH blocking.

---

## 5. Verification Gates

```bash
asl check asl-gateway/src/lmk.asl
asl check asl-gateway/src/wire.asl
asl check asl-gateway/src/server.asl
asl test asl-gateway/tests/lmk-test.asl
asl test asl-gateway/tests/wire-test.asl
asl test asl-gateway/tests/server-test.asl
```

---

## 6. In-Container Orchestration (`bin/asl-runner`)

For containerized environments (Modal, Docker, Harbor):
- `bin/asl-runner [command...]`: Self-contained entrypoint that verifies gateway daemon health on `http://127.0.0.1:8765/health`, auto-starts it if offline, exports `OPENAI_BASE_URL="http://127.0.0.1:8765/v1"` and `NO_PROXY="127.0.0.1,localhost"`, and executes the command under sovereign cognitive protection.
- `bin/asl-gateway run`: Runs the gateway in foreground mode as a supervisor entrypoint.
- Non-null sanitization: Guarantees `message.content` is always a valid string (never `null` or `NoneType`), eliminating verifier crashes across benchmark suites.

---

## 7. Modal Cloud & Terminal-Bench 4.0 Deployment

When running on Modal or Terminal-Bench:
```bash
# Export provider credentials into container environment:
export OPENROUTER_API_KEY="..." # or GEMINI_API_KEY, OPENAI_API_KEY
export ASL_GATEWAY_MODEL="gemma-4-31b-it"

# Execute agent self-contained:
bin/asl-runner bin/agent -p "Solve task"

# Or invoke Harbor runner under in-container gateway routing:
bin/asl-runner harbor run -d terminal-bench/terminal-bench@4.0.0 --environment modal
```

