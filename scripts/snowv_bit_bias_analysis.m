clc; clear;
fprintf("=== SNOW-V Bit-Level Bias Analysis ===\n\n");

%% ================= SETTINGS =================
num_runs  = 500;
num_bytes = 16;
num_bits  = 8;

if ~exist("run_results", "dir"); mkdir("run_results"); end
bias_sum      = zeros(num_bytes, num_bits);
total_samples = 0;   % track total fault-hit rows across all runs
valid_runs =0;
%% ================= LOOP OVER RUNS =================
for run = 1:num_runs

    fprintf("Processing run %d / %d ...\n", run, num_runs);

     % -------- File names --------
    file_clean  = sprintf("keystream_clean_key_%d.txt",    run);
    file_faulty = sprintf("keystream_faulty_key_%d.txt",   run);
    file_fault  = sprintf("fault_positions_key_%d.txt",  run);

     % -------- File existence check --------
    if ~isfile(file_clean) || ~isfile(file_faulty) || ~isfile(file_fault)
        warning("Run %d: missing files — skipping.", run);
        continue;
    end

    % -------- Load hex keystreams --------
    Zc = read_hex_file(file_clean);
    Zf = read_hex_file(file_faulty);

    % -------- Debug: verify data range on first run --------
    if run == 1
        fprintf("  [Debug] Zc  max=%d  min=%d\n", max(Zc(:)), min(Zc(:)));
        fprintf("  [Debug] Zf  max=%d  min=%d\n", max(Zf(:)), min(Zf(:)));
    end

    % -------- XOR differential --------
    DeltaZ = bitxor(Zc, Zf);

    % -------- Load fault positions and filter --------
fault_raw = readtable(file_fault, 'ReadVariableNames', false);
    t_hit = fault_raw{:,1};
    t_hit = t_hit(t_hit >= 1 & t_hit <= size(DeltaZ,1));

    if isempty(t_hit)
        warning("Run %d: no valid fault rows — skipping.", run);
        continue;
    end
    
    t_start = min(t_hit);
    DeltaZ = DeltaZ(t_start:end, :);
    n_fault = size(DeltaZ, 1);

fprintf("  Run %d | Fault-hit rows used: %d / %d\n", ...
            run, n_fault, size(Zc,1));

    if n_fault == 0
        warning("Run %d: no valid fault rows — skipping.", run);
        continue;
    end

    total_samples = total_samples + n_fault;
    valid_runs    = valid_runs + 1; 
    % -------- Compute bias for this run --------
    % pseudocode:
    %   p_{b,k} = (1/N) * sum_{t=1}^{N} bit_k( DeltaZ^(b)_t )
    %   eps_{b,k} = | p_{b,k} - 0.5 |
    bias_run = zeros(num_bytes, num_bits);
    for b = 1:num_bytes
        byte_vals = DeltaZ(:, b);
        for k = 1:num_bits
            bits             = double(bitget(byte_vals, k));
            p                = mean(bits);
            bias_run(b, k)   = abs(p - 0.5);
        end
    end
    bias_sum = bias_sum + bias_run;

    % -------- Save per-run TXT --------
    out_txt = sprintf("run_results/bias_run_%d.txt", run);
    fid = fopen(out_txt, 'w');
    fprintf(fid, "SNOW-V Bit-Level Bias -- Run %d\n", run);
    fprintf(fid, "Fault-hit samples: %d\n", n_fault);
    fprintf(fid, "Rows = Bytes (0-15)  |  Columns = Bits (k=0 LSB ... k=7 MSB)\n\n");
    fprintf(fid, "%-10s", "Byte\\Bit");
    for k = 0:7; fprintf(fid, "  k=%-6d", k); end
    fprintf(fid, "\n%s\n", repmat('-', 1, 76));
    for b = 1:num_bytes
        fprintf(fid, "Byte %-4d  ", b-1);
        fprintf(fid, "  %.4f  ", bias_run(b,:));
        fprintf(fid, "\n");
    end
    fclose(fid);

    % -------- Save per-run CSV --------
    writematrix(bias_run, sprintf("run_results/bias_run_%d.csv", run));

end  % end run loop

%% ================= AVERAGING =================
if valid_runs == 0
    error("No valid runs found. Check file paths.");
end
bias_avg = bias_sum / valid_runs;

fprintf("\nAveraging completed over %d valid runs (of %d total).\n", ...
        valid_runs, num_runs);
fprintf("Total fault-hit samples across all runs: %d\n\n", total_samples);

%% ================= SAVE AVERAGED RESULTS =================

% ---- Averaged TXT ----
fid = fopen("bit_bias_avg.txt", 'w');
fprintf(fid, "SNOW-V Bit-Level Bias -- AVERAGE over %d Runs\n", num_runs);
fprintf(fid, "Total fault-hit samples: %d\n\n", total_samples);
fprintf(fid, "Table: Bit-Level Bias Matrix epsilon(b,k)\n");
fprintf(fid, "Rows = Bytes (b=0..15)  |  Columns = Bits (k=0 LSB .. k=7 MSB)\n\n");
fprintf(fid, "%-10s", "Byte\\Bit");
for k = 0:7; fprintf(fid, "  k=%-8d", k); end
fprintf(fid, "\n%s\n", repmat('-', 1, 84));
for b = 1:num_bytes
    fprintf(fid, "Byte %-4d  ", b-1);
    fprintf(fid, "  %.6f  ", bias_avg(b,:));
    fprintf(fid, "\n");
end
fclose(fid);

% ---- Averaged CSV ----
writematrix(bias_avg, "bit_bias_avg.csv");

% ---- Gnuplot data ----
fid = fopen("bit_bias_avg_gnuplot.dat", 'w');
fprintf(fid, "# byte  bit  bias\n");
for b = 1:num_bytes
    for k = 1:num_bits
        fprintf(fid, "%d  %d  %.6f\n", b-1, k-1, bias_avg(b,k));
    end
    fprintf(fid, "\n");
end
fclose(fid);

fprintf("Saved: bit_bias_avg.txt | bit_bias_avg.csv | bit_bias_avg_gnuplot.dat\n\n");

%% ================= CONSOLE TABLE =================
fprintf("=== Averaged Bit-Level Bias  epsilon(b,k) ===\n");
fprintf("%-10s", "Byte\\Bit");
for k = 0:7; fprintf("  k=%-5d", k); end
fprintf("\n%s\n", repmat('-', 1, 74));
for b = 1:num_bytes
    fprintf("Byte %-4d  ", b-1);
    fprintf("  %.4f", bias_avg(b,:));
    fprintf("\n");
end

fprintf("=== Done ===\n");
%% ===================================================================
%  HEX FILE READER
%  Reads files where each line has 16 space-separated hex bytes
%  e.g.:  f5 2a 97 4f 4a d7 4a b1 07 cb 7c d0 91 dc 43 dc
%  Returns [N x 16] uint8 matrix
%% ===================================================================
function data = read_hex_file(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error("Cannot open file: %s", filename);
    end
    raw = fscanf(fid, '%2x');
    fclose(fid);
    if mod(length(raw), 16) ~= 0
        error("File format error in '%s': got %d bytes, not divisible by 16", ...
              filename, length(raw));
    end
    data = uint8(reshape(raw, 16, []).');
end
