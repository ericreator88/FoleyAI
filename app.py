"""
Foley AI — Local Web Application
Video → AI-generated sound effects
"""

import os
import sys
import time
import json
import uuid
import random
import threading
import webbrowser
import numpy as np
import torch
import torchaudio
from flask import Flask, request, jsonify, send_file, send_from_directory, Response
from werkzeug.utils import secure_filename
from loguru import logger

# ── Config ──────────────────────────────────────────────────────────────────
APP_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.join(APP_DIR, "repo")
MODEL_PATH = os.path.join(APP_DIR, "pretrained_models")
OUTPUT_DIR = os.path.join(APP_DIR, "output")
UPLOAD_DIR = os.path.join(APP_DIR, "uploads")
STATIC_DIR = os.path.join(APP_DIR, "static")
PORT = 8079

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ── Flask App ───────────────────────────────────────────────────────────────
app = Flask(__name__, static_folder=STATIC_DIR)
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024  # 500MB

# ── Global State ────────────────────────────────────────────────────────────
model_state = {
    "loaded": False,
    "loading": False,
    "model_dict": None,
    "cfg": None,
    "device": None,
    "model_size": None,
    "error": None,
}

jobs = {}


def set_seed(seed=1):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


# ── Model Loading ───────────────────────────────────────────────────────────
def load_models(model_size="xxl", enable_offload=False):
    from hunyuanvideo_foley.utils.model_utils import load_model

    model_state["loading"] = True
    model_state["error"] = None
    try:
        device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

        config_map = {
            "xl": os.path.join(REPO_DIR, "configs", "hunyuanvideo-foley-xl.yaml"),
            "xxl": os.path.join(REPO_DIR, "configs", "hunyuanvideo-foley-xxl.yaml"),
        }
        config_path = config_map[model_size]

        logger.info(f"Loading {model_size.upper()} model...")
        model_dict, cfg = load_model(
            MODEL_PATH, config_path, device,
            enable_offload=enable_offload, model_size=model_size
        )
        model_state.update({
            "model_dict": model_dict, "cfg": cfg,
            "device": device, "model_size": model_size, "loaded": True,
        })
        logger.info("Models loaded successfully")
    except Exception as e:
        model_state["error"] = str(e)
        logger.error(f"Model load failed: {e}")
    finally:
        model_state["loading"] = False


def run_inference(job_id, video_path, prompt, neg_prompt, guidance_scale, num_steps):
    from hunyuanvideo_foley.utils.feature_utils import feature_process
    from hunyuanvideo_foley.utils.model_utils import denoise_process
    from hunyuanvideo_foley.utils.media_utils import merge_audio_video

    job = jobs[job_id]
    try:
        job.update(status="processing", message="Extracting features...", progress=10)

        visual_feats, text_feats, audio_len_in_s = feature_process(
            video_path, prompt,
            model_state["model_dict"], model_state["cfg"],
            neg_prompt=neg_prompt if neg_prompt else None
        )

        job.update(message="Generating audio...", progress=25)

        audio, sample_rate = denoise_process(
            visual_feats, text_feats, audio_len_in_s,
            model_state["model_dict"], model_state["cfg"],
            guidance_scale=guidance_scale,
            num_inference_steps=num_steps,
        )

        job.update(message="Saving...", progress=85)

        base = secure_filename(os.path.splitext(os.path.basename(video_path))[0]) or "output"
        ts = int(time.time())
        audio_file = f"{base}_{ts}.wav"
        video_file = f"{base}_{ts}.mp4"
        audio_path = os.path.join(OUTPUT_DIR, audio_file)
        video_out = os.path.join(OUTPUT_DIR, video_file)

        torchaudio.save(audio_path, audio[0], sample_rate)

        job.update(message="Merging audio + video...", progress=90)
        merge_audio_video(audio_path, video_path, video_out)

        job.update(status="done", message="Complete!", progress=100,
                   output_video=video_file, output_audio=audio_file)
        logger.info(f"Job {job_id} complete: {video_file}")

    except Exception as e:
        job.update(status="error", message=str(e))
        logger.error(f"Job {job_id} failed: {e}")


# ── Routes ──────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    return send_file(os.path.join(STATIC_DIR, "index.html"))


@app.route("/api/status")
def api_status():
    gpu = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    mem = f"{torch.cuda.get_device_properties(0).total_memory / 1e9:.0f}GB" if torch.cuda.is_available() else "N/A"
    return jsonify({
        "model_loaded": model_state["loaded"],
        "model_loading": model_state["loading"],
        "model_size": model_state["model_size"],
        "model_error": model_state["error"],
        "gpu": gpu, "gpu_memory": mem,
        "cuda": torch.cuda.is_available(),
    })


@app.route("/api/load_model", methods=["POST"])
def api_load_model():
    if model_state["loading"]:
        return jsonify({"error": "Already loading"}), 409
    data = request.json or {}
    threading.Thread(
        target=load_models,
        args=(data.get("model_size", "xxl"), data.get("enable_offload", False)),
        daemon=True
    ).start()
    return jsonify({"message": "Loading..."})


@app.route("/api/generate", methods=["POST"])
def api_generate():
    if not model_state["loaded"]:
        return jsonify({"error": "Model not loaded"}), 400

    video = request.files.get("video")
    if not video:
        return jsonify({"error": "No video"}), 400

    filename = secure_filename(video.filename) or "upload.mp4"
    video_path = os.path.join(UPLOAD_DIR, f"{uuid.uuid4().hex[:8]}_{filename}")
    video.save(video_path)

    job_id = uuid.uuid4().hex[:12]
    jobs[job_id] = {
        "status": "queued", "progress": 0, "message": "Queued...",
        "output_video": None, "output_audio": None,
    }

    threading.Thread(
        target=run_inference,
        args=(job_id, video_path,
              request.form.get("prompt", ""),
              request.form.get("neg_prompt", ""),
              float(request.form.get("guidance_scale", 4.5)),
              int(request.form.get("num_steps", 50))),
        daemon=True
    ).start()

    return jsonify({"job_id": job_id})


@app.route("/api/job/<job_id>")
def api_job(job_id):
    return jsonify(jobs.get(job_id) or {"error": "Not found"})


@app.route("/api/job/<job_id>/stream")
def api_job_stream(job_id):
    def generate():
        while True:
            job = jobs.get(job_id)
            if not job:
                yield f"data: {json.dumps({'error': 'Not found'})}\n\n"
                break
            yield f"data: {json.dumps(job)}\n\n"
            if job["status"] in ("done", "error"):
                break
            time.sleep(0.5)
    return Response(generate(), mimetype="text/event-stream")


@app.route("/output/<path:filename>")
def serve_output(filename):
    return send_from_directory(OUTPUT_DIR, filename)


# ── Main ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logger.remove()
    logger.add(sys.stderr, level="INFO")
    set_seed(1)

    model_size = os.environ.get("MODEL_SIZE", "xxl").lower()
    offload = os.environ.get("ENABLE_OFFLOAD", "false").lower() in ("true", "1")

    logger.info(f"Foley AI starting on http://127.0.0.1:{PORT}")

    threading.Thread(target=load_models, args=(model_size, offload), daemon=True).start()

    def open_browser():
        time.sleep(2)
        webbrowser.open(f"http://127.0.0.1:{PORT}")
    threading.Thread(target=open_browser, daemon=True).start()

    app.run(host="127.0.0.1", port=PORT, debug=False, threaded=True)
