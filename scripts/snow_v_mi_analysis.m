clc; clear;
fprintf("=== SNOW-V Mutual Information Leakage Analysis ===\n\n");

%% ================= SETTINGS =================
num_runs  = 5XX; 
num_bytes = 16;
if ~exist("run_results_mi", "dir"); mkdir("run_results_mi"); end

all_mi_results = nan(num_runs, num_bytes); 
valid_runs_mask = false(num_runs, 1);

%% ================= LOOP OVER RUNS =================
for run = 1:num_runs
    fprintf("Processing run %d / %d ... ", run, num_runs);

    file_clean  = sprintf("keystream_clean_key_%d.txt",  run);
    file_faulty = sprintf("keystream_faulty_key_%d.txt", run);
    file_fault  = sprintf("fault_positions_key_%d.txt",  run);
    file_t1     = sprintf("t1_values_key_%d.txt",        run);
    
    if ~isfile(file_clean) || ~isfile(file_faulty) || ~isfile(file_fault) || ~isfile(file_t1)
        fprintf("Skipped (Missing files)\n");
        continue;
    end
    
    try
        Zc = read_hex_file(file_clean);
        Zf = read_hex_file(file_faulty);
        T1_raw = read_hex_file(file_t1);
        
       % XOR differential (Leakage Variable X)
        DeltaZ_full = bitxor(Zc, Zf);
        
        % Filter by Fault Hit (Persistent Region)
        fault_raw = readtable(file_fault, 'ReadVariableNames', false);
        t_hit = fault_raw{:,1};
        t_hit = t_hit(t_hit >= 1 & t_hit <= size(DeltaZ_full, 1));
        
        if isempty(t_hit)
            fprintf("Skipped (No valid faults)\n");
            continue;
        end
        
        t_start = min(t_hit);
        DeltaZ = DeltaZ_full(t_start:end, :);
        T1     = T1_raw(t_start:end, :); 
        n_fault = size(DeltaZ, 1);

        if n_fault < 10
            fprintf("Skipped (Too few samples)\n");
            continue;
        end
        
        %% ================= MI CALCULATION =================
        mi_run = zeros(1, num_bytes);
        for b = 1:num_bytes
            X = double(DeltaZ(:, b));
            Y = double(T1(:, b));
            
            % Marginal distributions
            px = histcounts(X, 0:256) / n_fault;
            py = histcounts(Y, 0:256) / n_fault;
            
            % Joint distribution
            pxy = histcounts2(X, Y, 0:256, 0:256) / n_fault;
            
            % Efficient MI Summation
            [i_idx, j_idx] = find(pxy > 0); 
            MI = 0;
            for k = 1:length(i_idx)
                r = i_idx(k);
                c = j_idx(k);
                if px(r) > 0 && py(c) > 0
                    MI = MI + pxy(r,c) * log2( pxy(r,c) / (px(r) * py(c)) );
                end
            end
            mi_run(b) = MI;
        end
        
        all_mi_results(run, :) = mi_run;
        valid_runs_mask(run) = true;
        fprintf("Done (N=%d, Mean MI=%.4f)\n", n_fault, mean(mi_run));

        %% ================= SAVE PER-KEY RESULTS =================
        out_txt = sprintf("run_results_mi/mi_bias_key_%d.txt", run);
        fid = fopen(out_txt, 'w');
        mean_mi = mean(mi_run);
        std_mi = std(mi_run);
        fprintf(fid, "Byte,MI_bits,Mean_MI,StdDev_MI\n");
        for b = 1:num_bytes
            fprintf(fid, "%d,%.10f,%.10f,%.10f\n", b-1, mi_run(b), mean_mi, std_mi);
        end
        fclose(fid);

    catch ME
        fprintf("Error in run %d: %s\n", run, ME.message);
    end
end 

%% ================= FINAL AGGREGATE STATS =================
valid_data = all_mi_results(valid_runs_mask, :);
num_valid = size(valid_data, 1);

if num_valid > 0
    mean_mi = mean(valid_data, 1);
    std_mi  = std(valid_data, 0, 1);
    
    % Save Final Aggregate Report
    report_name = 'run_results_mi/FINAL_MI_STATISTICS.txt';
    fid = fopen(report_name, 'w');
    fprintf(fid, "SNOW-V AGGREGATE MI STATISTICS (Runs: %d)\n", num_valid);
    fprintf(fid, "--------------------------------------------------\n");
    fprintf(fid, "%-8s | %-15s | %-15s\n", "Byte", "Mean MI", "Std Dev");
    fprintf(fid, "--------------------------------------------------\n");
    
    fprintf("\nFinal Statistics Across All Keys:\n");
    for b = 1:num_bytes
        line = sprintf("Byte %-3d | %15.8f | %15.8f\n", b-1, mean_mi(b), std_mi(b));
        fprintf(line);
        fprintf(fid, line);
    end
    fclose(fid);
    
    save('run_results_mi/summary_stats.mat', 'mean_mi', 'std_mi', 'num_valid');
    fprintf("\nResults saved to %s\n", report_name);
else
    warning("No valid runs were processed. Check your file naming or fault positions.");
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
