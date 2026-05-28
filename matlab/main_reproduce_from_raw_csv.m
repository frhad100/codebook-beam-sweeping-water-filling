function main_reproduce_from_raw_csv()
% MAIN_REPRODUCE_FROM_RAW_CSV
% Rebuilds the manuscript tables and figures from the archived raw CSV data.
% This script is intentionally data-driven so that the exact table/figure
% values included in the revised manuscript are reproducible from the saved
% user-level Monte Carlo outputs.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
rawDir   = fullfile(repoRoot, 'raw_csv');
figDir   = fullfile(repoRoot, 'figures_from_matlab');
if ~exist(figDir, 'dir'), mkdir(figDir); end

T = readtable(fullfile(rawDir, 'all_user_metrics_200snapshots.csv'));

coverageThreshold_dB = 3.0;
OH_total = 0.016071428571428573; % Stored in simulation_config.json

% Tables 3 and 4
Table3 = make_summary_table(T, 'sinr_cepta_dB', 'tput_cepta_Mbps', ...
                              'sinr_wf_pa_dB', 'tput_wf_pa_Mbps', ...
                              'CEPTA', 'WF_PA', coverageThreshold_dB, OH_total);
writetable(Table3, fullfile(rawDir, 'table3_cepta_vs_wf_pa_from_matlab.csv'));

Table4 = make_summary_table(T, 'sinr_cepta_dB', 'tput_cepta_Mbps', ...
                              'sinr_cepta_dB', 'tput_wf_ta_eta005_Mbps', ...
                              'CEPTA', 'WF_TA', coverageThreshold_dB, OH_total);
writetable(Table4, fullfile(rawDir, 'table4_cepta_vs_wf_ta_from_matlab.csv'));

% Table 5
etaVals = [0.05 0.20 0.35 0.50 0.70 1.00];
etaCols = {'tput_wf_ta_eta005_Mbps', 'tput_fc_wf_ta_eta020_Mbps', ...
           'tput_fc_wf_ta_eta035_Mbps', 'tput_fc_wf_ta_eta050_Mbps', ...
           'tput_fc_wf_ta_eta070_Mbps', 'tput_fc_wf_ta_eta100_Mbps'};
ceptaMean = mean(T.tput_cepta_Mbps);
MeanTput = zeros(numel(etaVals),1);
Gain = zeros(numel(etaVals),1);
JFI = zeros(numel(etaVals),1);
for ii = 1:numel(etaVals)
    x = T.(etaCols{ii});
    MeanTput(ii) = mean(x);
    Gain(ii) = 100*(MeanTput(ii)-ceptaMean)/ceptaMean;
    JFI(ii) = jain_fairness(x);
end
Table5 = table(etaVals(:), MeanTput, Gain, JFI, 'VariableNames', ...
    {'eta_T','Avg_effective_throughput_Mbps_per_user','Gain_over_CEPTA_percent','JFI_throughput'});
writetable(Table5, fullfile(rawDir, 'table5_fairness_sweep_from_matlab.csv'));

% Additional percentile table
pct = [1;5;10;25;50;75;90;95];
CEPTA_pct = prctile(T.sinr_cepta_dB, pct);
WFPA_pct = prctile(T.sinr_wf_pa_dB, pct);
PercentileTable = table(pct, CEPTA_pct, WFPA_pct, 'VariableNames', ...
    {'Percentile_percent','CEPTA_SINR_dB','WF_PA_SINR_dB'});
writetable(PercentileTable, fullfile(rawDir, 'additional_sinr_percentiles_from_matlab.csv'));

% Figures 3-11 from raw data
plot_hist2(T.sinr_cepta_dB, T.sinr_wf_pa_dB, 'CEPTA', 'WF-PA', 'SINR (dB)', ...
    'SINR Histogram (CEPTA vs WF-PA)', fullfile(figDir,'fig3_sinr_hist_cepta_wfpa.png'));
plot_cdf2(T.sinr_cepta_dB, T.sinr_wf_pa_dB, 'CEPTA', 'WF-PA', 'SINR (dB)', ...
    'SINR CDF (CEPTA vs WF-PA)', fullfile(figDir,'fig4_sinr_cdf_cepta_wfpa.png'));
plot_hist2(T.tput_cepta_Mbps, T.tput_wf_pa_Mbps, 'CEPTA', 'WF-PA', 'Effective throughput (Mbps/user)', ...
    'Effective Throughput Histogram (CEPTA vs WF-PA)', fullfile(figDir,'fig5_tput_hist_cepta_wfpa.png'));
plot_cdf2(T.tput_cepta_Mbps, T.tput_wf_pa_Mbps, 'CEPTA', 'WF-PA', 'Effective throughput (Mbps/user)', ...
    'Effective Throughput CDF (CEPTA vs WF-PA)', fullfile(figDir,'fig6_tput_cdf_cepta_wfpa.png'));
plot_hist2(T.sinr_cepta_dB, T.sinr_cepta_dB, 'CEPTA', 'WF-TA', 'SINR (dB)', ...
    'SINR Histogram (CEPTA vs WF-TA)', fullfile(figDir,'fig7_sinr_hist_cepta_wfta.png'));
plot_cdf2(T.sinr_cepta_dB, T.sinr_cepta_dB, 'CEPTA', 'WF-TA', 'SINR (dB)', ...
    'SINR CDF (CEPTA vs WF-TA)', fullfile(figDir,'fig8_sinr_cdf_cepta_wfta.png'));
plot_hist2(T.tput_cepta_Mbps, T.tput_wf_ta_eta005_Mbps, 'CEPTA', 'WF-TA', 'Effective throughput (Mbps/user)', ...
    'Effective Throughput Histogram (CEPTA vs WF-TA)', fullfile(figDir,'fig9_tput_hist_cepta_wfta.png'));
plot_cdf2(T.tput_cepta_Mbps, T.tput_wf_ta_eta005_Mbps, 'CEPTA', 'WF-TA', 'Effective throughput (Mbps/user)', ...
    'Effective Throughput CDF (CEPTA vs WF-TA)', fullfile(figDir,'fig10_tput_cdf_cepta_wfta.png'));

figure('Color','w');
plot(Table5.eta_T, Table5.Avg_effective_throughput_Mbps_per_user, '-o', 'LineWidth',1.5); grid on;
xlabel('\eta_T'); ylabel('Avg. effective throughput (Mbps/user)');
yyaxis right; plot(Table5.eta_T, Table5.JFI_throughput, '--s', 'LineWidth',1.5);
ylabel('JFI (throughput)');
title('Fairness-constrained WF-TA trade-off');
legend('Avg. effective throughput','JFI','Location','best');
exportgraphics(gcf, fullfile(figDir,'fig11_fairness_tradeoff_wfta.png'), 'Resolution', 300);
close(gcf);

disp(Table3); disp(Table4); disp(Table5); disp(PercentileTable);
fprintf('Raw-data reproduction completed. Outputs written to %s\n', figDir);
end

function S = make_summary_table(T, sinr1, tput1, sinr2, tput2, name1, name2, thr, OH_total)
metrics = {'Avg. SINR (dB)'; 'Avg. Effective Throughput (Mbps/user)'; ...
           'Coverage (SINR>3 dB) (% users)'; '5%-tile SINR (dB)'; ...
           'JFI (Throughput)'; 'Avg. PHY Throughput (Mbps/user)'};
A = compute_metrics(T.(sinr1), T.(tput1), thr, OH_total);
B = compute_metrics(T.(sinr2), T.(tput2), thr, OH_total);
S = table(metrics, A(:), B(:), 'VariableNames', {'Parameter', name1, name2});
end

function out = compute_metrics(sinr_dB, tput_eff, thr, OH_total)
out = [mean(sinr_dB); mean(tput_eff); 100*mean(sinr_dB > thr); prctile(sinr_dB,5); ...
       jain_fairness(tput_eff); mean(tput_eff)/(1-OH_total)];
end

function J = jain_fairness(x)
x = x(:); x(~isfinite(x)) = 0;
denom = length(x)*sum(x.^2);
if denom <= 0, J = 0; else, J = (sum(x)^2)/denom; end
end

function plot_hist2(x1, x2, label1, label2, xlab, ttl, fname)
figure('Color','w');
edges = linspace(min([x1; x2]), max([x1; x2]), 41);
histogram(x1, edges, 'FaceAlpha',0.55, 'DisplayName', label1); hold on;
histogram(x2, edges, 'FaceAlpha',0.55, 'DisplayName', label2); grid on;
xlabel(xlab); ylabel('Users'); title(ttl); legend('show','Location','best');
exportgraphics(gcf, fname, 'Resolution', 300); close(gcf);
end

function plot_cdf2(x1, x2, label1, label2, xlab, ttl, fname)
figure('Color','w');
x1 = sort(x1); y1 = (1:numel(x1))'/numel(x1);
x2 = sort(x2); y2 = (1:numel(x2))'/numel(x2);
plot(x1,y1,'LineWidth',1.5,'DisplayName',label1); hold on;
plot(x2,y2,'LineWidth',1.5,'DisplayName',label2); grid on;
xlabel(xlab); ylabel('CDF'); title(ttl); legend('show','Location','best');
exportgraphics(gcf, fname, 'Resolution', 300); close(gcf);
end
