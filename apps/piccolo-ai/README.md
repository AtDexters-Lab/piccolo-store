# Piccolo AI

Piccolo AI is the local OpenAI-compatible inference provider for Piccolo OS.
The catalog release serves the Qwen3-VL 4B Instruct model with INT4-compressed
OpenVINO weights and supports text and image inputs.

## Runtime profile

- Model API identifier: `piccolo-chat`
- API base path: `/v3`
- Default inference device: Intel GPU
- Compatibility fallback: CPU
- Minimum host memory: 12 GB
- Provider image: `ghcr.io/atdexters-lab/piccolo-ai-ovms:0.1.3`
- Model artifact:
  [`boris93/Qwen3-VL-4B-Instruct-int4-ov`](https://huggingface.co/boris93/Qwen3-VL-4B-Instruct-int4-ov)

The app uses OVMS continuous batching automatically. Clients do not select a
fixed batch size: one request can run immediately, while overlapping requests
are scheduled together subject to the runtime's sequence, token, cache, and
HTTP admission limits.

## Authentication

The public `/v3` API requires the bearer token generated during installation.
Save the token before installing because Piccolo cannot reveal the current
value afterward.

Piccolod-owned consumer apps use the protected `ai.inference.openai.v1`
capability listener instead of the public bearer-token path.
