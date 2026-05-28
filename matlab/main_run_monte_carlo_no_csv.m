function RESULTS = main_run_monte_carlo_no_csv()
% MAIN_RUN_MONTE_CARLO_NO_CSV
% -------------------------------------------------------------------------
% Corrected 200-snapshot Monte Carlo simulation for the paper:
% "Water-Filling Optimization for Codebook Beam Sweeping: Power Allocation
% versus Time-Resource Allocation"
%
% This version DOES NOT read or write any CSV files.
% It generates the results directly from the Monte Carlo simulation, prints
% the required tables in the MATLAB Command Window, stores everything in the
% output structure RESULTS, and optionally saves figures and one .mat file.
%
% Corrected modeling assumptions used to answer the INASS/IJIES comments:
%   1) 7 BSs, 3 sectors per BS, 21 active sectors.
%   2) Exactly 20 UEs are independently and uniformly generated inside each
%      active sector in every Monte Carlo snapshot.
%   3) No strongest-power reassociation is used. Therefore, the realized
%      sector load is fixed by construction: N_j = 20 for every sector.
%   4) The load-dependent activity factor is therefore fixed as
%      rho_j = rho_idle + (rho_active-rho_idle)*min(1,20/Nref) = 0.4833.
%   5) All schemes use the same UE positions, shadowing, beam sweeping, and
%      interference realization within each snapshot.
%   6) Coverage threshold is SINR > 3 dB.
%
% How to run:
%   RESULTS = main_run_monte_carlo_no_csv;
%
% Outputs:
%   RESULTS.Table3  : CEPTA vs WF-PA summary table
%   RESULTS.Table4  : CEPTA vs WF-TA summary table
%   RESULTS.Table5  : fairness-constrained WF-TA sweep
%   RESULTS.Table6  : 95% confidence intervals and standard deviations
%   RESULTS.Table7  : additional CEPTA/WF-PA SINR percentiles
%   RESULTS.Table8  : Monte Carlo convergence from 150 to 200 snapshots
%   RESULTS.allRows : user-level metrics for all snapshots
%   RESULTS.snapRows: snapshot-level metrics
%
% Notes:
%   - No CSV files are created by this script.
%   - For old MATLAB versions, figures are saved using print(), not
%     exportgraphics().
% -------------------------------------------------------------------------

clc; close all;
rng(31001, 'twister');

% User options
saveFigures = true;
saveMatFile = true;     % Saves one .mat file only, not CSV.
outDir = fullfile(pwd, 'mc_no_csv_outputs');
if (saveFigures || saveMatFile) && ~exist(outDir, 'dir')
    mkdir(outDir);
end

% -------------------------------------------------------------------------
% Simulation parameters
% -------------------------------------------------------------------------
P.numBS = 7;
P.numSec = 3;
P.UEsPerSec = 20;
P.Nsnap = 200;
P.BW_Hz = 100e6;
P.f_c_Hz = 28e9;
P.Pt_dBm = 33;
P.Pt_W = 10^((P.Pt_dBm - 30)/10);
P.NF_dB = 9;
P.noise_dBm = -174 + 10*log10(P.BW_Hz) + P.NF_dB;
P.noise_W = 10^((P.noise_dBm - 30)/10);
P.antennaGain_dBi = 15;
P.beamWidth_deg = 15;
P.codebookAngles = (P.beamWidth_deg/2):P.beamWidth_deg:(120 - P.beamWidth_deg/2);
P.numBeams = numel(P.codebookAngles);

% 5G-like SSB/CSI overhead model
P.mu = 3;
P.nSym_slot = 14;
P.nSym_SSB = 4;
P.T_slot_ms = 1/(2^P.mu);
P.Tsym_ms = P.T_slot_ms/P.nSym_slot;
P.T_SSB_ms = P.nSym_SSB*P.Tsym_ms;
P.T_ssb_period_ms = 20;
P.T_csi_period_ms = 5;
P.OH_SSB = P.numBeams*P.T_SSB_ms/P.T_ssb_period_ms;
P.OH_CSI = P.Tsym_ms/P.T_csi_period_ms;
P.OH_total = min(P.OH_SSB + P.OH_CSI, 0.5);

% Load/activity and propagation assumptions
P.rho_active = 0.70;
P.rho_idle = 0.05;
P.Nref = 30;
P.rho = P.rho_idle + (P.rho_active - P.rho_idle)*min(1, P.UEsPerSec/P.Nref);
P.eta_overlap = 0.50;
P.p_correct_beam = 0.90;
P.sigmaSh_dB = 4;
P.coverageThreshold_dB = 3.0;

% Site coordinates: central site plus six surrounding sites within 1 km x 1 km
P.bsPos = [500 500;
           800 500;
           200 500;
           650 760;
           650 240;
           350 760;
           350 240];

% Fairness-constrained WF-TA normalized floor factors eta_T.
% The actual minimum time share is tau_min = eta_T/K_s.
P.etaVals = [0.05 0.20 0.35 0.50 0.70 1.00];

fprintf('\nCorrected Monte Carlo simulation without CSV files\n');
fprintf('Snapshots: %d, UEs/snapshot: %d, total user samples: %d\n', ...
    P.Nsnap, P.numBS*P.numSec*P.UEsPerSec, P.Nsnap*P.numBS*P.numSec*P.UEsPerSec);
fprintf('Fixed sector load N_j = %d, activity factor rho_j = %.4f\n', P.UEsPerSec, P.rho);
fprintf('Overhead: OH_SSB = %.4f, OH_CSI = %.4f, OH_total = %.4f\n\n', ...
    P.OH_SSB, P.OH_CSI, P.OH_total);

% -------------------------------------------------------------------------
% Monte Carlo loop
% -------------------------------------------------------------------------
allRows = table();
snapRows = table();

for snap = 1:P.Nsnap
    R = simulate_one_snapshot(P, snap);
    allRows = [allRows; R]; %#ok<AGROW>
    snapRows = [snapRows; snapshot_metrics(R, snap, P)]; %#ok<AGROW>
    if mod(snap,50) == 0
        fprintf('Completed snapshot %d / %d\n', snap, P.Nsnap);
    end
end

% -------------------------------------------------------------------------
% Tables required for revised manuscript and reviewer response
% -------------------------------------------------------------------------
Table3 = make_summary_table(allRows, 'sinr_cepta_dB', 'tput_cepta_Mbps', ...
    'sinr_wf_pa_dB', 'tput_wf_pa_Mbps', 'CEPTA', 'WF_PA', P);

Table4 = make_summary_table(allRows, 'sinr_cepta_dB', 'tput_cepta_Mbps', ...
    'sinr_cepta_dB', 'tput_wf_ta_eta005_Mbps', 'CEPTA', 'WF_TA', P);

etaCols = {'tput_wf_ta_eta005_Mbps', ...
           'tput_fc_wf_ta_eta020_Mbps', ...
           'tput_fc_wf_ta_eta035_Mbps', ...
           'tput_fc_wf_ta_eta050_Mbps', ...
           'tput_fc_wf_ta_eta070_Mbps', ...
           'tput_fc_wf_ta_eta100_Mbps'};
MeanTput = zeros(numel(P.etaVals),1);
Gain = zeros(numel(P.etaVals),1);
JFI = zeros(numel(P.etaVals),1);
ceptaMean = mean(allRows.tput_cepta_Mbps);
for ii = 1:numel(P.etaVals)
    x = allRows.(etaCols{ii});
    MeanTput(ii) = mean(x);
    Gain(ii) = 100*(MeanTput(ii) - ceptaMean)/ceptaMean;
    JFI(ii) = jain_fairness(x);
end
Table5 = table(P.etaVals(:), MeanTput, Gain, JFI, ...
    'VariableNames', {'eta_T','Avg_effective_throughput_Mbps_per_user', ...
    'Gain_over_CEPTA_percent','JFI_throughput'});

Table6 = make_ci_table(snapRows);

pct = [1; 5; 10; 25; 50; 75; 90; 95];
Table7 = table(pct, prctile(allRows.sinr_cepta_dB,pct), prctile(allRows.sinr_wf_pa_dB,pct), ...
    'VariableNames', {'Percentile_percent','CEPTA_SINR_dB','WF_PA_SINR_dB'});

Table8 = make_convergence_table(allRows);

% -------------------------------------------------------------------------
% Print tables in Command Window, no CSV output
% -------------------------------------------------------------------------
fprintf('\n================ TABLE 3: CEPTA vs WF-PA ================\n');
disp(Table3);
fprintf('\n================ TABLE 4: CEPTA vs WF-TA ================\n');
disp(Table4);
fprintf('\n================ TABLE 5: FC-WF-TA sweep ================\n');
disp(Table5);
fprintf('\n================ TABLE 6: 95%% confidence intervals ================\n');
disp(Table6);
fprintf('\n================ TABLE 7: Additional SINR percentiles ================\n');
disp(Table7);
fprintf('\n================ TABLE 8: MC convergence, 150 vs 200 snapshots ================\n');
disp(Table8);

% -------------------------------------------------------------------------
% Figures, generated directly from the simulation
% -------------------------------------------------------------------------
if saveFigures
    plot_hist2(allRows.sinr_cepta_dB, allRows.sinr_wf_pa_dB, 'CEPTA', 'WF-PA', ...
        'SINR (dB)', 'SINR Histogram: CEPTA vs WF-PA', fullfile(outDir,'fig3_sinr_hist_cepta_wfpa.png'));
    plot_cdf2(allRows.sinr_cepta_dB, allRows.sinr_wf_pa_dB, 'CEPTA', 'WF-PA', ...
        'SINR (dB)', 'SINR CDF: CEPTA vs WF-PA', fullfile(outDir,'fig4_sinr_cdf_cepta_wfpa.png'));
    plot_hist2(allRows.tput_cepta_Mbps, allRows.tput_wf_pa_Mbps, 'CEPTA', 'WF-PA', ...
        'Effective throughput (Mbps/user)', 'Effective Throughput Histogram: CEPTA vs WF-PA', fullfile(outDir,'fig5_tput_hist_cepta_wfpa.png'));
    plot_cdf2(allRows.tput_cepta_Mbps, allRows.tput_wf_pa_Mbps, 'CEPTA', 'WF-PA', ...
        'Effective throughput (Mbps/user)', 'Effective Throughput CDF: CEPTA vs WF-PA', fullfile(outDir,'fig6_tput_cdf_cepta_wfpa.png'));

    % WF-TA changes time-resource weights but uses the same SINR distribution.
    plot_hist2(allRows.sinr_cepta_dB, allRows.sinr_cepta_dB, 'CEPTA', 'WF-TA', ...
        'SINR (dB)', 'SINR Histogram: CEPTA vs WF-TA', fullfile(outDir,'fig7_sinr_hist_cepta_wfta.png'));
    plot_cdf2(allRows.sinr_cepta_dB, allRows.sinr_cepta_dB, 'CEPTA', 'WF-TA', ...
        'SINR (dB)', 'SINR CDF: CEPTA vs WF-TA', fullfile(outDir,'fig8_sinr_cdf_cepta_wfta.png'));
    plot_hist2(allRows.tput_cepta_Mbps, allRows.tput_wf_ta_eta005_Mbps, 'CEPTA', 'WF-TA', ...
        'Effective throughput (Mbps/user)', 'Effective Throughput Histogram: CEPTA vs WF-TA', fullfile(outDir,'fig9_tput_hist_cepta_wfta.png'));
    plot_cdf2(allRows.tput_cepta_Mbps, allRows.tput_wf_ta_eta005_Mbps, 'CEPTA', 'WF-TA', ...
        'Effective throughput (Mbps/user)', 'Effective Throughput CDF: CEPTA vs WF-TA', fullfile(outDir,'fig10_tput_cdf_cepta_wfta.png'));

    figure('Color','w');
    plot(Table5.eta_T, Table5.Avg_effective_throughput_Mbps_per_user, '-o', 'LineWidth', 1.5);
    grid on;
    xlabel('\eta_T');
    ylabel('Avg. effective throughput (Mbps/user)');
    yyaxis right;
    plot(Table5.eta_T, Table5.JFI_throughput, '--s', 'LineWidth', 1.5);
    ylabel('Jain fairness index');
    title('Fairness-constrained WF-TA trade-off');
    legend('Avg. effective throughput','JFI','Location','best');
    save_png_compat(gcf, fullfile(outDir,'fig11_fairness_tradeoff_wfta.png'));
    close(gcf);
end

% -------------------------------------------------------------------------
% Return everything in one MATLAB structure and optionally save .mat
% -------------------------------------------------------------------------
RESULTS = struct();
RESULTS.P = P;
RESULTS.allRows = allRows;
RESULTS.snapRows = snapRows;
RESULTS.Table3 = Table3;
RESULTS.Table4 = Table4;
RESULTS.Table5 = Table5;
RESULTS.Table6 = Table6;
RESULTS.Table7 = Table7;
RESULTS.Table8 = Table8;

if saveMatFile
    save(fullfile(outDir,'MC_RESULTS_no_csv.mat'), 'RESULTS', '-v7.3');
end

fprintf('\nDone. No CSV files were created.\n');
if saveFigures || saveMatFile
    fprintf('Output folder: %s\n', outDir);
end
end

% =========================================================================
% Local functions
% =========================================================================
function R = simulate_one_snapshot(P, snap)
N = P.numBS*P.numSec*P.UEsPerSec;
user = zeros(N,4);
row = 0;

% Exactly 20 UEs are generated inside each active sector.
for bs = 1:P.numBS
    sx = P.bsPos(bs,1);
    sy = P.bsPos(bs,2);
    for sec = 1:P.numSec
        az0 = (sec-1)*120;
        az1 = sec*120;
        r = sqrt(rand(P.UEsPerSec,1))*150;
        az = az0 + rand(P.UEsPerSec,1)*(az1 - az0);
        x = sx + r.*cosd(az);
        y = sy + r.*sind(az);
        idx = row + (1:P.UEsPerSec);
        user(idx,:) = [bs*ones(P.UEsPerSec,1), sec*ones(P.UEsPerSec,1), x, y];
        row = row + P.UEsPerSec;
    end
end

bsIdx = user(:,1);
secIdx = user(:,2);
x = user(:,3);
y = user(:,4);
g_eff = zeros(N,1);
I_W = zeros(N,1);
sweep_ms = zeros(N,1);

allPairs = zeros(P.numBS*P.numSec,2);
c = 0;
for b = 1:P.numBS
    for s = 1:P.numSec
        c = c + 1;
        allPairs(c,:) = [b s];
    end
end

for u = 1:N
    b = bsIdx(u);
    s = secIdx(u);
    xb = P.bsPos(b,1);
    yb = P.bsPos(b,2);

    th = atan2d(y(u)-yb, x(u)-xb);
    if th < 0, th = th + 360; end
    thLocal = th - (s-1)*120;
    if thLocal < 0, thLocal = thLocal + 360; end
    if thLocal >= 120, thLocal = 120 - eps; end

    d = hypot(x(u)-xb, y(u)-yb);
    PL = path_loss_uma_simple(d, P.f_c_Hz) + P.sigmaSh_dB*randn;

    delta = abs(wrap180_local(thLocal - P.codebookAngles));
    G_all = beam_gain(delta, P.beamWidth_deg, P.antennaGain_dBi, 30);
    Pr = 10.^((P.Pt_dBm + G_all - PL - 30)/10);
    [~, bestIdx] = max(Pr/P.noise_W);

    chosenIdx = bestIdx;
    if rand > P.p_correct_beam
        neigh = [bestIdx-1, bestIdx+1];
        neigh = neigh(neigh >= 1 & neigh <= P.numBeams);
        if ~isempty(neigh)
            chosenIdx = neigh(randi(numel(neigh)));
        end
    end

    g_eff(u) = 10^((G_all(chosenIdx) - PL)/10);

    tBest = (bestIdx-1)*P.T_SSB_ms;
    tArrival = rand*P.T_ssb_period_ms;
    if tArrival <= tBest
        sweep_ms(u) = tBest - tArrival;
    else
        sweep_ms(u) = P.T_ssb_period_ms - tArrival + tBest;
    end

    % Load-aware inter-sector interference from all non-serving sectors.
    I = 0;
    for k = 1:size(allPairs,1)
        bI = allPairs(k,1);
        sI = allPairs(k,2);
        if bI == b && sI == s
            continue;
        end

        xbI = P.bsPos(bI,1);
        ybI = P.bsPos(bI,2);
        thI = atan2d(y(u)-ybI, x(u)-xbI);
        if thI < 0, thI = thI + 360; end
        thILocal = thI - (sI-1)*120;
        if thILocal < 0, thILocal = thILocal + 360; end
        if thILocal >= 120, thILocal = 120 - eps; end

        interferingBeam = P.codebookAngles(randi(P.numBeams));
        GI = beam_gain(abs(wrap180_local(thILocal - interferingBeam)), ...
            P.beamWidth_deg, P.antennaGain_dBi, 30);
        dI = hypot(x(u)-xbI, y(u)-ybI);
        PLI = path_loss_uma_simple(dI, P.f_c_Hz) + P.sigmaSh_dB*randn;
        I = I + P.eta_overlap*P.rho*10^((P.Pt_dBm + GI - PLI - 30)/10);
    end
    I_W(u) = I;
end

N_eff = P.noise_W + I_W;
gamma = g_eff ./ N_eff;

% CEPTA SINR
sinr_cepta = P.Pt_W*g_eff ./ N_eff;

% WF-PA and WF-TA allocations are computed independently for each sector.
P_alloc = zeros(N,1);
w = zeros(N,numel(P.etaVals));
for b = 1:P.numBS
    for s = 1:P.numSec
        idx = find(bsIdx == b & secIdx == s);
        gam = gamma(idx);
        P_alloc(idx) = water_fill_alloc(gam, numel(idx)*P.Pt_W, 0.05);
        for ii = 1:numel(P.etaVals)
            w(idx,ii) = water_fill_alloc(gam, 1, P.etaVals(ii));
        end
    end
end

sinr_wfpa = P_alloc.*g_eff ./ N_eff;

tput_cepta = P.BW_Hz/P.UEsPerSec*log2(1 + sinr_cepta)/1e6*(1 - P.OH_total);
tput_wfpa  = P.BW_Hz/P.UEsPerSec*log2(1 + sinr_wfpa)/1e6*(1 - P.OH_total);
tput_eta = zeros(N,numel(P.etaVals));
for ii = 1:numel(P.etaVals)
    tput_eta(:,ii) = P.BW_Hz*w(:,ii).*log2(1 + sinr_cepta)/1e6*(1 - P.OH_total);
end

R = table(repmat(snap,N,1), bsIdx, secIdx, x, y, g_eff, I_W, ...
    sinr_cepta, sinr_wfpa, 10*log10(sinr_cepta), 10*log10(sinr_wfpa), ...
    tput_cepta, tput_wfpa, tput_eta(:,1), tput_eta(:,2), tput_eta(:,3), ...
    tput_eta(:,4), tput_eta(:,5), tput_eta(:,6), sweep_ms, ...
    'VariableNames', {'snapshot','bs','sector','x_m','y_m','g_eff','interference_W', ...
    'sinr_cepta_linear','sinr_wf_pa_linear','sinr_cepta_dB','sinr_wf_pa_dB', ...
    'tput_cepta_Mbps','tput_wf_pa_Mbps','tput_wf_ta_eta005_Mbps', ...
    'tput_fc_wf_ta_eta020_Mbps','tput_fc_wf_ta_eta035_Mbps', ...
    'tput_fc_wf_ta_eta050_Mbps','tput_fc_wf_ta_eta070_Mbps', ...
    'tput_fc_wf_ta_eta100_Mbps','sweep_time_ms'});
end

function PLdB = path_loss_uma_simple(d_m, f_Hz)
% Close, simple UMa-like path-loss expression used for reproducible runs.
% If your manuscript states the full 3GPP TR 38.901 UMa LOS/NLOS model,
% replace this function with the exact TR 38.901 implementation used in the
% submitted version before final repository release.
f_GHz = f_Hz/1e9;
d_m = max(d_m, 1);
PLdB = 32.4 + 21*log10(d_m) + 20*log10(f_GHz);
end

function G = beam_gain(delta, HPBW, Gmax, Am)
G = Gmax - min(12*(delta./HPBW).^2, Am);
end

function ang = wrap180_local(ang)
ang = mod(ang + 180, 360) - 180;
end

function a = water_fill_alloc(gamma, total, eta)
% Truncated water-filling allocation.
% For WF-PA: total = K_s*P_t and eta = 0.05.
% For WF-TA: total = 1 and eta = eta_T, so tau_min = eta_T/K_s.
gamma = gamma(:);
K = numel(gamma);
a = zeros(K,1);
if K == 0 || total <= 0
    return;
end
equalShare = total/K;
minInd = eta*equalShare;
rem = total - K*minInd;
if rem <= 0
    a(:) = equalShare;
    return;
end
invG = 1./max(gamma, eps);
active = true(K,1);
while true
    Kactive = sum(active);
    if Kactive == 0
        a(:) = equalShare;
        return;
    end
    mu = (rem + sum(invG(active)))/Kactive;
    tmp = mu - invG;
    newActive = tmp > 0;
    if all(newActive == active)
        wf = max(tmp,0);
        swf = sum(wf);
        if swf > 0
            wf = wf*(rem/swf);
        end
        a = minInd + wf;
        a = a*(total/sum(a));
        return;
    end
    active = newActive;
end
end

function S = snapshot_metrics(R, snap, P)
vals = [metric_vec(R.sinr_cepta_dB,R.tput_cepta_Mbps,P), ...
        metric_vec(R.sinr_wf_pa_dB,R.tput_wf_pa_Mbps,P), ...
        metric_vec(R.sinr_cepta_dB,R.tput_wf_ta_eta005_Mbps,P), ...
        metric_vec(R.sinr_cepta_dB,R.tput_fc_wf_ta_eta050_Mbps,P)];
S = array2table([snap vals], 'VariableNames', {'snapshot', ...
    'CEPTA_AvgSINR_dB','CEPTA_AvgEffTput_Mbps','CEPTA_Coverage_pct','CEPTA_P5SINR_dB','CEPTA_JFI','CEPTA_AvgPHYTput_Mbps', ...
    'WFPA_AvgSINR_dB','WFPA_AvgEffTput_Mbps','WFPA_Coverage_pct','WFPA_P5SINR_dB','WFPA_JFI','WFPA_AvgPHYTput_Mbps', ...
    'WFTA_AvgSINR_dB','WFTA_AvgEffTput_Mbps','WFTA_Coverage_pct','WFTA_P5SINR_dB','WFTA_JFI','WFTA_AvgPHYTput_Mbps', ...
    'FCWFTA050_AvgSINR_dB','FCWFTA050_AvgEffTput_Mbps','FCWFTA050_Coverage_pct','FCWFTA050_P5SINR_dB','FCWFTA050_JFI','FCWFTA050_AvgPHYTput_Mbps'});
end

function v = metric_vec(sinr_dB, tput, P)
v = [mean(sinr_dB), ...
     mean(tput), ...
     100*mean(sinr_dB > P.coverageThreshold_dB), ...
     prctile(sinr_dB,5), ...
     jain_fairness(tput), ...
     mean(tput)/(1 - P.OH_total)];
end

function S = make_summary_table(T, sinr1, tput1, sinr2, tput2, name1, name2, P)
metrics = {'Avg. SINR (dB)'; ...
           'Avg. Effective Throughput (Mbps/user)'; ...
           'Coverage (SINR > 3 dB) (% users)'; ...
           '5%-tile SINR (dB)'; ...
           'JFI (Throughput)'; ...
           'Avg. PHY Throughput (Mbps/user)'};
A = metric_vec(T.(sinr1), T.(tput1), P);
B = metric_vec(T.(sinr2), T.(tput2), P);
S = table(metrics, A(:), B(:), 'VariableNames', {'Parameter', name1, name2});
end

function CI = make_ci_table(S)
vars = S.Properties.VariableNames;
vars = vars(2:end);
Metric = vars(:);
Mean = zeros(numel(vars),1);
StdDev = zeros(numel(vars),1);
CI95 = zeros(numel(vars),1);
for i = 1:numel(vars)
    x = S.(vars{i});
    Mean(i) = mean(x);
    StdDev(i) = std(x);
    CI95(i) = 1.96*std(x)/sqrt(numel(x));
end
CI = table(Metric, Mean, StdDev, CI95, ...
    'VariableNames', {'Metric','Mean','StdDev_across_snapshots','CI95_half_width'});
end

function C = make_convergence_table(T)
Scheme = {'CEPTA'; 'WF-PA'; 'WF-TA'; 'FC-WF-TA eta=0.50'};
cols = {'tput_cepta_Mbps', 'tput_wf_pa_Mbps', 'tput_wf_ta_eta005_Mbps', 'tput_fc_wf_ta_eta050_Mbps'};
T150 = zeros(4,1);
T200 = zeros(4,1);
Rel = zeros(4,1);
for i = 1:4
    T150(i) = mean(T.(cols{i})(T.snapshot <= 150));
    T200(i) = mean(T.(cols{i}));
    Rel(i) = 100*(T200(i) - T150(i))/T150(i);
end
C = table(Scheme, T150, T200, Rel, ...
    'VariableNames', {'Scheme','Avg_eff_throughput_150_snapshots', ...
    'Avg_eff_throughput_200_snapshots','Relative_change_percent'});
end

function J = jain_fairness(x)
x = x(:);
x(~isfinite(x)) = 0;
den = numel(x)*sum(x.^2);
if den <= 0
    J = 0;
else
    J = (sum(x)^2)/den;
end
end

function plot_hist2(x1, x2, l1, l2, xlab, ttl, fname)
figure('Color','w');
mn = min([x1(:); x2(:)]);
mx = max([x1(:); x2(:)]);
if mx <= mn
    mx = mn + 1;
end
edges = linspace(mn, mx, 41);
histogram(x1, edges, 'FaceAlpha', 0.55, 'DisplayName', l1);
hold on;
histogram(x2, edges, 'FaceAlpha', 0.55, 'DisplayName', l2);
grid on;
xlabel(xlab);
ylabel('Users');
title(ttl);
legend('show','Location','best');
save_png_compat(gcf, fname);
close(gcf);
end

function plot_cdf2(x1, x2, l1, l2, xlab, ttl, fname)
figure('Color','w');
x1 = sort(x1(:));
x2 = sort(x2(:));
y1 = (1:numel(x1))'/numel(x1);
y2 = (1:numel(x2))'/numel(x2);
plot(x1, y1, 'LineWidth', 1.5, 'DisplayName', l1);
hold on;
plot(x2, y2, 'LineWidth', 1.5, 'DisplayName', l2);
grid on;
xlabel(xlab);
ylabel('CDF');
title(ttl);
legend('show','Location','best');
save_png_compat(gcf, fname);
close(gcf);
end

function save_png_compat(figHandle, fname)
set(figHandle, 'PaperPositionMode', 'auto');
print(figHandle, fname, '-dpng', '-r300');
end
