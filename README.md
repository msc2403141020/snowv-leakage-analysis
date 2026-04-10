# SNOW-V Persistent Fault Analysis (PFA)

> **Quantifying information-theoretic leakage in the SNOW-V stream cipher under hardware-level persistent S-box fault injection.**

This repository provides the implementation and statistical framework for identifying side-channel leakage in **SNOW-V**. By utilizing persistent fault models, this research characterizes statistical biases in keystream differentials and quantifies entropy loss using **Mutual Information (MI)**.

## 🎓 Research Context
* **Institution:** Indian Institute of Technology (IIT) Indore
* **Department:** Department of Mathematics
* **Focus:** Hardware Security, Cryptanalysis, SNOW-V Stream Cipher

---


## 📂 Repository Structure

```text
├── scripts/
│   ├── snowv_bit_bias_analysis.m    # Bit-level bias analysis (ε = |p - 0.5|)
│   ├── snowv_byte_bias_analysis.m   # Byte-level distribution and frequency analysis
│   └── snow_v_mi_analysis.m         # Per-byte Mutual Information (MI) leakage calculation
├── snowv-correct-model/             # Reference C implementation of fault-free SNOW-V
├── snowv_sbox_strong_fault_model.c  # C implementation with persistent fault injection logic
└── .gitignore                       # Standard exclusions for data logs (.txt, .mat)
```



## ⚙️ How It Works
```
### 1 — Keystream Generation (C)

The analysis begins by generating two keystreams using identical **Key–IV pairs** to isolate the fault impact.

| Stream | Description |
|--------|------------|
| Zc (Clean) | Reference fault-free keystream |
| Zf (Faulty) | Keystream with a persistent S-box fault injected into R2 / R3 registers |

The specific cycles where the persistent fault is active are logged to `fault_positions_key_n.txt` to ensure precise alignment during analysis.
---

### 2 — Differential Analysis
We focus exclusively on the XOR differential between the two streams:

ΔZ = Zc XOR Zf

The analysis pipeline automatically discards transient phases and only retains samples where the **persistent fault** actively influences the output.
---
```


### 3 — Bias Analysis (MATLAB)
```
The analysis is performed over:

- 500+ independent trials  
- Each with $10^6$ keystream samples  
- Totaling 3.9M+ fault-hit observations  

---
```

#### A. Bit-Level Bias
We calculate the bias $\epsilon$ for every bit position:

ε = |p − 0.5|


- `ε ≈ 0` → output is pseudorandom
- `ε > 0` → statistical bias present
- persistent `ε > 0` → **internal state leakage confirmed**


#### B. Byte-Level & MI Analysis
* **Byte Bias:** Measures the deviation of 8-bit blocks from the uniform distribution $$
  \frac{1}{256}
  $$.
* **Mutual Information:** Quantifies the exact bits of entropy leaked from the $T_1$ register into the $\Delta Z$ differential.
---



## 📂 Output Files
```

| File | Contents |
|------|----------|
| `bit_bias_avg.csv` | Aggregated bias matrix |
| `byte_bias.csv` | Byte-level distribution data |
| `MI_STATISTICS.txt` | Mean and standard deviation of leakage |
```

---

## 🚀 Usage

### Requirements
* **Data:** Generated `.txt` keystream files (clean, faulty, and fault-position logs) in the working directory.
* **Software:** MATLAB R2022b or later.

### Execution
```
Run the analysis scripts in sequence:
```matlab
% 1. Analyze bit-level biases
run('scripts/snowv_bit_bias_analysis.m')

% 2. Analyze byte-level distribution
run('scripts/snowv_byte_bias_analysis.m')

% 3. Calculate Mutual Information leakage
run('scripts/snow_v_mi_analysis.m')
```
