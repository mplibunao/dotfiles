#!/usr/bin/env python3
"""Kokoro daemon worker (stdin/stdout NDJSON)."""

import json
import math
import os
import sys
from typing import Any, Dict, Optional

import numpy as np
import onnxruntime as ort
import soundfile as sf
from ttstokenizer import IPATokenizer

WORKER_PROTOCOL_VERSION = 1
EXPECTED_SAMPLE_RATE = 24000
BASELINE_WPM = 175.0
MIN_WPM = 80.0
MAX_WPM = 300.0
MIN_SPEED = 0.5
MAX_SPEED = 2.0


def eprint(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def emit(payload: Dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def load_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def select_providers(coreml_mode: Optional[str]) -> list[str]:
    available = ort.get_available_providers()
    mode = (coreml_mode or "auto").strip().lower()
    if mode not in ("auto", "on", "off"):
        mode = "auto"

    if mode != "off" and "CoreMLExecutionProvider" in available:
        return ["CoreMLExecutionProvider", "CPUExecutionProvider"]

    if mode == "on" and "CoreMLExecutionProvider" not in available:
        eprint("CoreMLExecutionProvider not available; falling back to CPU")

    return ["CPUExecutionProvider"]


def create_session(model_path: str, providers: list[str]) -> ort.InferenceSession:
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    return ort.InferenceSession(model_path, sess_options=options, providers=providers)


def coerce_speed(rate_wpm: Any) -> Optional[float]:
    if rate_wpm is None:
        return 1.0

    try:
        wpm = float(rate_wpm)
    except (TypeError, ValueError):
        return None

    if not math.isfinite(wpm):
        return None

    if wpm < MIN_WPM:
        wpm = MIN_WPM
    if wpm > MAX_WPM:
        wpm = MAX_WPM

    speed = wpm / BASELINE_WPM
    if speed < MIN_SPEED:
        speed = MIN_SPEED
    if speed > MAX_SPEED:
        speed = MAX_SPEED

    return speed


def is_safe_job_id(job_id: str) -> bool:
    if os.sep in job_id:
        return False
    if os.altsep and os.altsep in job_id:
        return False
    return True


def synthesize(
    request: Dict[str, Any],
    voices: Dict[str, Any],
    default_voice: str,
    tokenizer: IPATokenizer,
    session: ort.InferenceSession,
    tmp_dir: str,
) -> str:
    job_id = request.get("jobId")
    if not isinstance(job_id, str) or not job_id:
        raise ValueError("Invalid jobId")
    if not is_safe_job_id(job_id):
        raise ValueError("Unsafe jobId")

    text = request.get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Empty text")

    voice = request.get("voice")
    if voice is None:
        voice = default_voice
    if not isinstance(voice, str) or voice not in voices:
        raise ValueError("Unknown voice")

    speed = coerce_speed(request.get("rate_wpm"))
    if speed is None:
        raise ValueError("Invalid rate_wpm")

    tokens = list(tokenizer(text))

    speaker = np.asarray(voices[voice], dtype=np.float32)
    if speaker.ndim == 1:
        style = speaker
    elif speaker.ndim == 2:
        idx = min(len(tokens), speaker.shape[0] - 1)
        if idx < 0:
            idx = 0
        style = speaker[idx]
    else:
        raise ValueError(f"Unexpected voice embedding shape: {speaker.shape}")

    input_tokens = np.array([[0, *tokens, 0]], dtype=np.int64)
    inputs = {
        "tokens": input_tokens,
        "style": np.asarray(style, dtype=np.float32),
        "speed": np.array([speed], dtype=np.float32),
    }

    outputs = session.run(None, inputs)
    audio = np.asarray(outputs[0]).squeeze()
    if audio.ndim != 1:
        raise ValueError(f"Unexpected audio shape: {audio.shape}")

    os.makedirs(tmp_dir, exist_ok=True)
    out_path = os.path.join(tmp_dir, f"{job_id}.wav")
    sf.write(out_path, audio, EXPECTED_SAMPLE_RATE)
    return out_path


def handle_providers_only() -> int:
    providers = ort.get_available_providers()
    emit({"providers": providers})
    return 0


def main() -> int:
    if "--providers" in sys.argv[1:]:
        return handle_providers_only()

    model_path = os.environ.get("KOKORO_MODEL_PATH")
    voices_path = os.environ.get("KOKORO_VOICES_PATH")
    if not model_path or not voices_path:
        eprint("Missing KOKORO_MODEL_PATH or KOKORO_VOICES_PATH")
        return 1

    voices = load_json(voices_path)
    if not isinstance(voices, dict) or not voices:
        eprint("Invalid voices file")
        return 1

    default_voice = next(iter(voices.keys()))
    tokenizer = IPATokenizer()
    providers = select_providers(os.environ.get("CCCTL_KOKORO_COREML"))
    session = create_session(model_path, providers)

    emit({
        "type": "ready",
        "v": WORKER_PROTOCOL_VERSION,
        "voices": sorted(str(key) for key in voices.keys()),
    })

    tmp_dir = os.environ.get(
        "CCCTL_KOKORO_TMP_DIR",
        os.path.join(os.path.expanduser("~"), ".claude", "ccctl", "tts", "tmp"),
    )

    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            eprint("Worker received invalid JSON")
            continue

        if not isinstance(request, dict):
            eprint("Worker received non-object request")
            continue

        if request.get("type") != "synthesize":
            eprint("Worker received unknown request type")
            continue

        job_id = request.get("jobId")
        try:
            out_path = synthesize(request, voices, default_voice, tokenizer, session, tmp_dir)
        except Exception as exc:
            eprint(f"Synthesis failed: {exc}")
            emit({
                "jobId": job_id if isinstance(job_id, str) else "unknown",
                "ok": False,
                "error": str(exc),
            })
            continue

        emit({
            "jobId": job_id,
            "ok": True,
            "out_path": out_path,
            "sr": EXPECTED_SAMPLE_RATE,
        })

    return 0


if __name__ == "__main__":
    sys.exit(main())
