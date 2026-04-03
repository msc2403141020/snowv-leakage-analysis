# SNOW-V Leakage Analysis

Implementation and experimental evaluation of **information-theoretic leakage** in the SNOW-V stream cipher under **persistent fault injection models**.

This project investigates how faults in the AES S-box propagate into the keystream, leading to measurable **statistical biases** and potential leakage of internal state information.

---

## 📂 Repository Structure
├── scripts/
│ └── snowv_bit_bias_analysis.m # MATLAB script for bit-level bias analysis (ε)
│
├── snowv-correct-model/ # Fault-free SNOW-V C implementation
├── snowv_sbox_strong_fault_model.c # Fault-injected SNOW-V (persistent S-box fault)
│
├── .gitignore # Ignores run_results/ and temporary files

---

## 🚀 Analysis Workflow

### 1. Data Generation (C)

The C implementations generate hex-encoded keystreams using identical **Key–IV pairs**.

Two datasets are produced:

- **Clean Keystream**: \( Z_c \)
- **Faulty Keystream**: \( Z_f \)

**Fault Logging:**
- Clock cycles where faulted registers (**R2/R3**) are active are recorded in:
- fault_positions_key_n.txt
- 
---

### 2. Differential Computation

The keystream differential is computed as:

\[
\Delta Z = Z_c \oplus Z_f
\]

Only **fault-hit samples** are considered for further analysis.

---

### 3. Statistical Bias Analysis (MATLAB)

The MATLAB script (`scripts/snowv_bit_bias_analysis.m`) performs automated analysis over **500+ independent runs**.

#### Key Steps:

- **Filtering**  
Extracts samples where fault propagation occurs.

- **Probability Estimation**  
Computes probability \( p \) of each bit being 1.

- **Bias Measurement**  
\[
\epsilon = |p - 0.5|
\]

---

### 🔍 Interpretation

- If \( \epsilon \approx 0 \): Output behaves randomly  
- If \( \epsilon > 0 \): Indicates **statistical bias**  
- Persistent non-zero bias ⇒ **information leakage from internal state**

---

## 📊 Output

The script generates:

- `bit_bias_avg.csv` → Aggregated bias matrix  
- `bit_bias_avg_gnuplot.dat` → Heatmap visualization input  

These results are computed over:

- **501 runs**
- Each with \( 10^6 \) keystream samples
- Over **3.9M+ fault-hit observations**

---

## ▶️ Usage

### Prerequisites

- MATLAB (tested on **R2022b or later**)
- Generated keystream `.txt` files in the working directory

---

### Execution

```matlab
run('scripts/snowv_bit_bias_analysis.m')
