clc; clear;
fprintf("=== SNOW-V Hamming-Weight Bias Analysis ===\n\n");

%% ================= SETTINGS =================
num_runs  = 5XX; 
num_bytes = 16;
if ~exist("run_results_hw", "dir"); mkdir("run_results_hw"); end

global_hw_sum = zeros(num_bytes, 1);
global_n_total = 0;

%% ================= LOOP OVER RUNS =================
for run = 1:num_runs
    fprintf("Processing run %d / %d ...\n", run, num_runs);
    
    file_clean  = sprintf("keystream_clean_key_%d.txt",  run);
    file_faulty = sprintf("keystream_faulty_key_%d.txt", run);
    file_fault  = sprintf("fault_positions_key_%d.txt",  run);
    
    % -------- File existence check --------
    if ~isfile(file_clean) || ~isfile(file_faulty) || ~isfile(file_fault)
        warning("Run %d: missing files — skipping.", run);
        continue;
    end

    % -------- Load hex keystreams --------
    Zc = read_hex_file(file_clean);
    Zf = read_hex_file(file_faulty);
    
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

    fprintf("  Run %d | Persistent region: [%d → %d] | Samples used: %d\n", ...
            run, t_start, size(Zc,1), n_fault);
    
    if n_fault == 0
        warning("Run %d: no valid fault rows — skipping.", run);
        continue;
    end
    % -------- Compute HW --------
     %   hw_t^(b)  = sum_{k=1}^{8} bit_k( DeltaZ^(b)_t )
    %   E[HW]_b   = mean_t( hw_t^(b) )
    %   beta_b    = | E[HW]_b - 4 |
    mean_hw_run = zeros(num_bytes, 1);
    hw_bias_run = zeros(num_bytes, 1);
    
    for b = 1:num_bytes
        
        % sum(bitget, 2) gets HW of each row; sum(...) gets total for column
       byte_vals = uint8(DeltaZ(:, b));
       current_hw_vec = zeros(n_fault, 1);
       for k = 1:8
           current_hw_vec = current_hw_vec + double(bitget(byte_vals, k));
       end
        
        % For Local Run
        mean_hw_run(b) = mean(current_hw_vec);
        hw_bias_run(b) = abs(mean_hw_run(b) - 4);
        
        % For Global Aggregate
        global_hw_sum(b) = global_hw_sum(b) + sum(current_hw_vec);
    end
    mean_beta = mean(hw_bias_run);   % scalar summary for this key

    global_n_total = global_n_total + n_fault;
     % -------- Key label --------
     if run == 501
        key_label = "All-00";
    elseif run == 502
        key_label = "All-FF";
    else
        key_label = sprintf("Random-%d", run);
     end

    %% ================= PRINT RESULTS =================

    fprintf("\n  Key %d Results:\n", run);
    fprintf("  %-10s  %-12s  %-12s\n", "Byte", "E[HW]", "|E[HW]-4|");
    fprintf("  %s\n", repmat('-', 1, 38));
    for b = 1:num_bytes
        fprintf("  Byte %-4d  %12.6f  %12.6f\n", b-1, mean_hw_run(b), hw_bias_run(b));
    end
    fprintf("  %s\n", repmat('-', 1, 38));
    fprintf("  Mean beta_HW = %.6f\n\n", mean_beta);

    % -------- Save per-key TXT --------
    out_txt = sprintf("run_results_hw/hw_bias_key_%d.txt", run);
    fid = fopen(out_txt, 'w');
    fprintf(fid, "SNOW-V HW Bias -- Key %d (%s)\n", run, key_label);
     fprintf(fid, "Persistent samples used: %d\n\n", n_fault);
    fprintf(fid, "%-10s  %-12s  %-12s\n", "Byte", "E[HW]", "|E[HW]-4|");
    fprintf(fid, "%s\n", repmat('-', 1, 38));
    for b = 1:num_bytes
        fprintf(fid, "Byte %-4d  %12.6f  %12.6f\n", b-1, mean_hw_run(b), hw_bias_run(b));
    end
    fprintf(fid, "%s\n", repmat('-', 1, 38));
    fprintf(fid, "Mean beta_HW  %12.6f\n", mean_beta);
    fclose(fid);

    % -------- Save per-key CSV --------
    % Columns: Byte (0-15), E[HW], |E[HW]-4|
    out_csv = sprintf("run_results_hw/hw_bias_key_%d.csv", run);
    T = table((0:num_bytes-1)', mean_hw_run, hw_bias_run, ...
              'VariableNames', {'Byte', 'E_HW', 'HW_Bias'});
    writetable(T, out_csv);

end 

%% ================= AGGREGATE RESULTS =================
if global_n_total > 0
    final_mean_hw = global_hw_sum / global_n_total;
    final_beta_hw = abs(final_mean_hw - 4);
    
    fprintf('\n%s\n', repmat('=', 1, 50));
    fprintf('MACROSCOPIC AGGREGATE RESULTS (N = %d)\n', global_n_total);
    fprintf('%s\n', repmat('=', 1, 50));
    fprintf('%-8s  %-12s  %-12s\n', 'Byte', 'E[HW]', 'Beta_HW');
    
    % Save to one final summary file
    fid = fopen('run_results_hw/AGGREGATE_LEAKAGE_REPORT.txt', 'w');
    fprintf(fid, "=== SNOW-V MACROSCOPIC LEAKAGE REPORT ===\n");
    fprintf(fid, "Total Samples Pooled: %d\n\n", global_n_total);
    fprintf(fid, "%-8s  %-12s  %-12s\n", 'Byte', 'E[HW]', 'Beta_HW');
    
    for b = 1:num_bytes
        res_str = sprintf('Byte %-3d  %12.6f  %12.6f\n', b-1, final_mean_hw(b), final_beta_hw(b));
        fprintf(res_str);
        fprintf(fid, res_str);
    end
    fclose(fid);
    fprintf('\nAggregate report saved to: run_results_hw/AGGREGATE_LEAKAGE_REPORT.txt\n');
else
    warning("No data was aggregated. Check file paths.");
end

%% ================= HEX FILE READER =================
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
