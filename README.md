# Foley AI

Generate realistic sound effects from any video using AI. Drop in a video, describe the sound you want, get back a video with perfectly synced audio.

Built on [HunyuanVideo-Foley](https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley) (Tencent) — current state-of-the-art in video-to-audio generation.

https://github.com/user-attachments/assets/placeholder

---

## Quick Start

### 1. Download this repo

```
git clone https://github.com/yourname/FoleyAI.git
```

Or download as ZIP and extract.

### 2. Run setup

Double-click **`setup.bat`**

That's it. Setup automatically:
- Installs Python 3.10 (locally, no admin needed)
- Installs PyTorch + CUDA
- Installs all dependencies
- Downloads model weights (~18GB, one-time)
- Creates a desktop shortcut

First run takes 15–30 minutes depending on your internet.

### 3. Use it

Double-click **`Foley AI`** on your desktop, or run **`foley-app.bat`**.

The web UI opens in your browser. Drag in a video, type a sound description, hit Generate.

---

## Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| **GPU** | NVIDIA with 8GB VRAM | NVIDIA with 16GB+ VRAM |
| **OS** | Windows 10/11 | Windows 10/11 |
| **Disk** | 30GB free | 40GB free |
| **RAM** | 16GB | 32GB |
| **Software** | [Git](https://git-scm.com/download/win) | Git |

> **No NVIDIA GPU?** This won't work on AMD, Intel, or CPU-only machines. The model requires CUDA.

---

## Usage

### Web UI (recommended)

```
foley-app.bat
```

Opens a browser interface at `http://127.0.0.1:8079`. Drag and drop videos, adjust settings, download results.

### Command Line

```bash
# Basic — video + sound description
foley video.mp4 "tires screeching on asphalt, engine revving"

# No prompt — model infers sound from video content
foley video.mp4

# Use lighter model (faster, less VRAM)
foley --xl video.mp4 "footsteps on gravel"

# Fewer steps (faster, slightly lower quality)
foley --steps 25 video.mp4 "rain on a tin roof"

# Batch process from CSV
foley --batch videos.csv

# Launch web UI from CLI
foley --app
```

### CLI Options

| Flag | Description | Default |
|---|---|---|
| `--xl` | Use XL model (16GB VRAM / 8GB with offload) | XXL |
| `--xxl` | Use XXL model (20GB VRAM / 12GB with offload) | XXL |
| `--offload` | CPU offload for low-VRAM GPUs | Off |
| `--steps N` | Denoising steps (lower = faster) | 50 |
| `--cfg N` | Guidance scale (higher = more prompt adherence) | 4.5 |
| `--out DIR` | Output directory | `./output` |

### Batch CSV Format

```csv
index,video,prompt
0,path/to/video1.mp4,"crunching gravel footsteps"
1,path/to/video2.mp4,"rain hitting a window"
2,path/to/video3.mp4,"car engine starting"
```

---

## Models

| Model | Quality | VRAM | VRAM (offload) | Speed |
|---|---|---|---|---|
| **XXL** (default) | Best | 20GB | 12GB | ~18s/clip |
| **XL** | Good | 16GB | 8GB | ~10s/clip |

Speeds measured on RTX 3090 at 50 steps.

---

## How It Works

The model uses a flow-matching diffusion transformer that takes video frames + text description and generates 48kHz audio synchronized to the visual content. It encodes video with SigLIP2 (visual understanding) and Synchformer (temporal alignment), encodes text with CLAP, then runs a denoising process to generate audio latents that are decoded by a custom audio VAE.

---

## Folder Structure

```
FoleyAI/
├── setup.bat              ← Run once to install everything
├── foley-app.bat          ← Launch web UI
├── foley.bat              ← CLI tool
├── app.py                 ← Web server
├── static/index.html      ← Web UI frontend
├── repo/                  ← HunyuanVideo-Foley source (created by setup)
├── pretrained_models/     ← Model weights (created by setup)
├── output/                ← Generated files
├── env/                   ← Python environment (created by setup)
└── README.md
```

---

## Troubleshooting

**"Git not found" during setup**
Install Git from https://git-scm.com/download/win and re-run setup.

**"CUDA not available"**
Make sure you have an NVIDIA GPU and updated drivers. Download latest from https://www.nvidia.com/drivers

**Model download fails**
Re-run `setup.bat` — it picks up where it left off. Or manually download from https://huggingface.co/tencent/HunyuanVideo-Foley and place `.pth` files in `pretrained_models/`.

**Out of VRAM**
Use the XL model: `foley --xl --offload video.mp4 "description"`

**App won't start / port in use**
Kill any existing Python processes and try again. Or change the port in `app.py` (line `PORT = 8079`).

---

## Known Limitations

- **Speech**: This is a sound effects model, not a speech model. It generates environmental audio, foley, and music — not intelligible dialogue.
- **Background music**: The model sometimes adds unwanted background music. Use negative prompts like "no music, no background music" to reduce this.
- **Video length**: Works best with clips under 30 seconds.

---

## Credits

- [HunyuanVideo-Foley](https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley) by Tencent Hunyuan
- [Paper: arXiv:2508.16930](https://arxiv.org/abs/2508.16930)

---

## License

The model weights and original code are subject to [Tencent's license](https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley/blob/main/LICENSE). This wrapper is MIT.
