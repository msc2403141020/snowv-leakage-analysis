# SNOW-V Leakage Analysis

> Information-theoretic leakage in SNOW-V under persistent S-box fault injection.

This project evaluates how AES S-box faults propagate into the SNOW-V keystream, producing measurable **statistical biases** that expose internal cipher state.

---

## Repository Structure

```
├── scripts/
│   └── snowv_bit_bias_analysis.m   # MATLAB: bit-level bias analysis
│   └── snowv_byte_bias_analysis.m   # MATLAB: byte-level bias analysis
├── snowv-correct-model/            # Fault-free SNOW-V (C)
├── snowv_sbox_strong_fault_model.c # Fault-injected SNOW-V (C)
└── .gitignore
```

---

## How It Works

### 1 — Keystream Generation (C)

Two keystreams are generated from identical Key–IV pairs:

| Stream | Description |
|--------|-------------|
| `Zc`   | Clean (fault-free) |
| `Zf`   | Faulty (persistent S-box fault in R2/R3) |

Active fault cycles are logged to `fault_positions_key_n.txt`.

### 2 — Differential

```
ΔZ = Zc XOR Zf
```

Only samples where faults actively hit the output are retained.

### 3 — Bias Analysis (MATLAB)

Run over **500+ independent trials**, each with 10⁶ keystream samples:

```
ε = |p − 0.5|
```

- `ε ≈ 0` → output is pseudorandom
- `ε > 0` → statistical bias present
- persistent `ε > 0` → **internal state leakage confirmed**

---

## Output Files

| File | Contents |
|------|----------|
| `bit_bias_avg.csv` | Aggregated bias matrix |
| `bit_bias_avg_gnuplot.dat` | Heatmap-ready data |

Computed over **3.9M+ fault-hit observations**.

---

## Usage

**Requirements:** MATLAB R2022b+, generated `.txt` keystream files in working directory.

```matlab
run('scripts/snowv_bit_bias_analysis.m')
run('scripts/snowv_byte_bias_analysis.m')
```
