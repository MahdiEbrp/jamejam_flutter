# soroush — Notification / Alert

**Role:** Notification service, AI funnel, provider abstraction.

**Key files / classes:**
- `soroush_controller.dart` — `SoroushController`.
- `soroush_service.dart` — `SoroushService`, `SoroushClient`, `HttpSoroushClient`.
- `ai_call_record.dart` / `ai_funnel.dart` — `AiCallRecord`, `AiFunnel`, `PromptMarkers`.
- `providers/` — `AnthropicProvider`, `OpenAICompatibleProvider`.

**Usage:** Send prompt → call provider → record result → notify.

**Contracts / why:** Provider abstraction allows swap; prompt markers control injection; call records preserve audit.

**AI fast-read:** `soroush_service.dart`; `ai_funnel.dart` for prompt flow.
