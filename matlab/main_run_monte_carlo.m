function main_run_monte_carlo()
% MAIN_RUN_MONTE_CARLO
% Corrected 200-snapshot Monte Carlo simulation for codebook beam sweeping
% with CEPTA, WF-PA, WF-TA, and fairness-constrained WF-TA.
%
% Corrected modeling assumptions:
%   - 7 BS sites, 3 sectors per BS, exactly 20 UEs per sector.
%   - UEs are uniformly randomized inside their assigned sector in every
%     snapshot; no strongest-power re-association is performed.
%   - Hence N_j = 20 for every active sector and rho_j = 0.4833.
%   - Coverage threshold is SINR > 3 dB.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
rawDir   = fullfile(repoRoot, 'raw_csv_matlab_run');
figDir   = fullfile(repoRoot, 'figures_matlab_run');
if ~exist(rawDir, 'dir'), mkdir(rawDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

rng(31001, 'twister');

% Parameters
P.numBS = 7; P.numSec = 3; P.UEsPerSec = 20; P.Nsnap = 200;
P.BW_Hz = 100e6; P.f_c_Hz = 28e9; P.Pt_dBm = 33; P.Pt_W = 10^((P.Pt_dBm-30)/10);
P.NF_dB = 9; P.noise_dBm = -174 + 10*log10(P.BW_Hz) + P.NF_dB;
P.noise_W = 10^((P.noise_dBm-30)/10);
P.antennaGain_dBi = 15; P.beamWidth_deg = 15;
P.codebookAngles = (P.beamWidth_deg/2):P.beamWidth_deg:(120-P.beamWidth_deg/2);
P.numBeams = numel(P.codebookAngles);
P.mu = 3; P.nSym_slot = 14; P.nSym_SSB = 4;
P.T_slot_ms = 1/(2^P.mu); P.Tsym_ms = P.T_slot_ms/P.nSym_slot;
P.T_SSB_ms = P.nSym_SSB*P.Tsym_ms;
P.OH_SSB = P.numBeams*P.T_SSB_ms/20;
P.OH_CSI = P.Tsym_ms/5;
P.OH_total = min(P.OH_SSB+P.OH_CSI, 0.5);
P.rho_active = 0.70; P.rho_idle = 0.05; P.Nref = 30;
P.rho = P.rho_idle + (P.rho_active-P.rho_idle)*min(1, P.UEsPerSec/P.Nref);
P.eta_overlap = 0.50; P.p_correct_beam = 0.90; P.sigmaSh_dB = 4;
P.coverageThreshold_dB = 3.0;
P.bsPos = [500 500; 800 500; 200 500; 650 760; 650 240; 350 760; 350 240];
P.etaVals = [0.05 0.20 0.35 0.50 0.70 1.00];

allRows = table();
snapshotRows = table();

for snap = 1:P.Nsnap
    R = simulate_snapshot(P, snap);
    allRows = [allRows; R]; %#ok<AGROW>
    snapshotRows = [snapshotRows; snapshot_metrics(R, snap, P)]; %#ok<AGROW>
    if mod(snap,50)==0
        fprintf('Completed snapshot %d / %d\n', snap, P.Nsnap);
    end
end

writetable(allRows, fullfile(rawDir,'all_user_metrics_200snapshots.csv'));
writetable(snapshotRows, fullfile(rawDir,'snapshot_level_metrics.csv'));

% Summary tables
Table3 = make_summary_table(allRows, 'sinr_cepta_dB', 'tput_cepta_Mbps', ...
    'sinr_wf_pa_dB', 'tput_wf_pa_Mbps', 'CEPTA', 'WF_PA', P);
writetable(Table3, fullfile(rawDir,'table3_cepta_vs_wf_pa.csv'));
Table4 = make_summary_table(allRows, 'sinr_cepta_dB', 'tput_cepta_Mbps', ...
    'sinr_cepta_dB', 'tput_wf_ta_eta005_Mbps', 'CEPTA', 'WF_TA', P);
writetable(Table4, fullfile(rawDir,'table4_cepta_vs_wf_ta.csv'));

% Fairness sweep table
etaCols = {'tput_wf_ta_eta005_Mbps','tput_fc_wf_ta_eta020_Mbps', ...
           'tput_fc_wf_ta_eta035_Mbps','tput_fc_wf_ta_eta050_Mbps', ...
           'tput_fc_wf_ta_eta070_Mbps','tput_fc_wf_ta_eta100_Mbps'};
MeanTput = zeros(numel(P.etaVals),1); Gain = zeros(numel(P.etaVals),1); JFI = zeros(numel(P.etaVals),1);
ceptaMean = mean(allRows.tput_cepta_Mbps);
for ii = 1:numel(P.etaVals)
    x = allRows.(etaCols{ii});
    MeanTput(ii) = mean(x); Gain(ii) = 100*(MeanTput(ii)-ceptaMean)/ceptaMean; JFI(ii) = jain_fairness(x);
end
Table5 = table(P.etaVals(:), MeanTput, Gain, JFI, 'VariableNames', ...
    {'eta_T','Avg_effective_throughput_Mbps_per_user','Gain_over_CEPTA_percent','JFI_throughput'});
writetable(Table5, fullfile(rawDir,'table5_fairness_sweep.csv'));

% Additional percentiles and convergence
pct = [1;5;10;25;50;75;90;95];
PctTable = table(pct, prctile(allRows.sinr_cepta_dB,pct), prctile(allRows.sinr_wf_pa_dB,pct), ...
    'VariableNames', {'Percentile_percent','CEPTA_SINR_dB','WF_PA_SINR_dB'});
writetable(PctTable, fullfile(rawDir,'additional_sinr_percentiles_cepta_vs_wf_pa.csv'));

CI = make_ci_table(snapshotRows);
writetable(CI, fullfile(rawDir,'confidence_intervals_200snapshots.csv'));
Conv = make_convergence_table(allRows);
writetable(Conv, fullfile(rawDir,'monte_carlo_convergence_150_vs_200.csv'));

% Figures from generated MATLAB run
plot_hist2(allRows.sinr_cepta_dB, allRows.sinr_wf_pa_dB, 'CEPTA', 'WF-PA', 'SINR (dB)', 'SINR Histogram (CEPTA vs WF-PA)', fullfile(figDir,'fig3_sinr_hist_cepta_wfpa.png'));
plot_cdf2(allRows.sinr_cepta_dB, allRows.sinr_wf_pa_dB, 'CEPTA', 'WF-PA', 'SINR (dB)', 'SINR CDF (CEPTA vs WF-PA)', fullfile(figDir,'fig4_sinr_cdf_cepta_wfpa.png'));
plot_hist2(allRows.tput_cepta_Mbps, allRows.tput_wf_pa_Mbps, 'CEPTA', 'WF-PA', 'Effective throughput (Mbps/user)', 'Effective Throughput Histogram (CEPTA vs WF-PA)', fullfile(figDir,'fig5_tput_hist_cepta_wfpa.png'));
plot_cdf2(allRows.tput_cepta_Mbps, allRows.tput_wf_pa_Mbps, 'CEPTA', 'WF-PA', 'Effective throughput (Mbps/user)', 'Effective Throughput CDF (CEPTA vs WF-PA)', fullfile(figDir,'fig6_tput_cdf_cepta_wfpa.png'));
plot_hist2(allRows.sinr_cepta_dB, allRows.sinr_cepta_dB, 'CEPTA', 'WF-TA', 'SINR (dB)', 'SINR Histogram (CEPTA vs WF-TA)', fullfile(figDir,'fig7_sinr_hist_cepta_wfta.png'));
plot_cdf2(allRows.sinr_cepta_dB, allRows.sinr_cepta_dB, 'CEPTA', 'WF-TA', 'SINR (dB)', 'SINR CDF (CEPTA vs WF-TA)', fullfile(figDir,'fig8_sinr_cdf_cepta_wfta.png'));
plot_hist2(allRows.tput_cepta_Mbps, allRows.tput_wf_ta_eta005_Mbps, 'CEPTA', 'WF-TA', 'Effective throughput (Mbps/user)', 'Effective Throughput Histogram (CEPTA vs WF-TA)', fullfile(figDir,'fig9_tput_hist_cepta_wfta.png'));
plot_cdf2(allRows.tput_cepta_Mbps, allRows.tput_wf_ta_eta005_Mbps, 'CEPTA', 'WF-TA', 'Effective throughput (Mbps/user)', 'Effective Throughput CDF (CEPTA vs WF-TA)', fullfile(figDir,'fig10_tput_cdf_cepta_wfta.png'));

figure('Color','w');
plot(Table5.eta_T, Table5.Avg_effective_throughput_Mbps_per_user, '-o', 'LineWidth',1.5); grid on;
xlabel('\eta_T'); ylabel('Avg. effective throughput (Mbps/user)');
yyaxis right; plot(Table5.eta_T, Table5.JFI_throughput, '--s', 'LineWidth',1.5);
ylabel('JFI (throughput)'); title('Fairness-constrained WF-TA trade-off');
legend('Avg. effective throughput','JFI','Location','best');
exportgraphics(gcf, fullfile(figDir,'fig11_fairness_tradeoff_wfta.png'), 'Resolution',300); close(gcf);

fprintf('Completed corrected Monte Carlo run. Outputs are in %s and %s\n', rawDir, figDir);
end

function R = simulate_snapshot(P, snap)
N = P.numBS*P.numSec*P.UEsPerSec;
user = zeros(N,4); row = 0;
for bs = 1:P.numBS
    sx = P.bsPos(bs,1); sy = P.bsPos(bs,2);
    for sec = 1:P.numSec
        az0 = (sec-1)*120; az1 = sec*120;
        r = sqrt(rand(P.UEsPerSec,1))*150;
        az = az0 + rand(P.UEsPerSec,1)*(az1-az0);
        x = sx + r.*cosd(az); y = sy + r.*sind(az);
        idx = row + (1:P.UEsPerSec);
        user(idx,:) = [bs*ones(P.UEsPerSec,1), sec*ones(P.UEsPerSec,1), x, y];
        row = row + P.UEsPerSec;
    end
end

bsIdx = user(:,1); secIdx = user(:,2); x = user(:,3); y = user(:,4);
g_eff = zeros(N,1); I_W = zeros(N,1); sweep_ms = zeros(N,1);
allPairs = zeros(P.numBS*P.numSec,2); c = 0;
for b = 1:P.numBS
    for s = 1:P.numSec
        c = c+1; allPairs(c,:) = [b s];
    end
end

for u = 1:N
    b = bsIdx(u); s = secIdx(u); xb = P.bsPos(b,1); yb = P.bsPos(b,2);
    th = atan2d(y(u)-yb, x(u)-xb); if th<0, th=th+360; end
    thLocal = th - (s-1)*120; if thLocal<0, thLocal=thLocal+360; end; if thLocal>=120, thLocal=120-eps; end
    d = hypot(x(u)-xb, y(u)-yb);
    PL = path_loss(d,P.f_c_Hz) + P.sigmaSh_dB*randn;
    delta = abs(wrap180_local(thLocal - P.codebookAngles));
    G_all = beam_gain(delta,P.beamWidth_deg,P.antennaGain_dBi,30);
    Pr = 10.^((P.Pt_dBm + G_all - PL - 30)/10);
    [~, bestIdx] = max(Pr/P.noise_W);
    chosenIdx = bestIdx;
    if rand > P.p_correct_beam
        neigh = [bestIdx-1, bestIdx+1]; neigh = neigh(neigh>=1 & neigh<=P.numBeams);
        if ~isempty(neigh), chosenIdx = neigh(randi(numel(neigh))); end
    end
    g_eff(u) = 10^((G_all(chosenIdx)-PL)/10);
    tBest = (bestIdx-1)*P.T_SSB_ms; tArrival = rand*20;
    if tArrival <= tBest, sweep_ms(u) = tBest-tArrival; else, sweep_ms(u) = 20-tArrival+tBest; end
    I = 0;
    for k = 1:size(allPairs,1)
        bI = allPairs(k,1); sI = allPairs(k,2);
        if bI==b && sI==s, continue; end
        xbI = P.bsPos(bI,1); ybI = P.bsPos(bI,2);
        thI = atan2d(y(u)-ybI, x(u)-xbI); if thI<0, thI=thI+360; end
        thILocal = thI - (sI-1)*120; if thILocal<0, thILocal=thILocal+360; end; if thILocal>=120, thILocal=120-eps; end
        bores = P.codebookAngles(randi(P.numBeams));
        GI = beam_gain(abs(wrap180_local(thILocal-bores)),P.beamWidth_deg,P.antennaGain_dBi,30);
        dI = hypot(x(u)-xbI, y(u)-ybI);
        PLI = path_loss(dI,P.f_c_Hz) + P.sigmaSh_dB*randn;
        I = I + P.eta_overlap*P.rho*10^((P.Pt_dBm+GI-PLI-30)/10);
    end
    I_W(u) = I;
end

N_eff = P.noise_W + I_W;
gamma = g_eff ./ N_eff;
sinr_cepta = P.Pt_W*g_eff ./ N_eff;
P_alloc = zeros(N,1);
w = zeros(N,numel(P.etaVals));
for b = 1:P.numBS
    for s = 1:P.numSec
        idx = find(bsIdx==b & secIdx==s);
        gam = gamma(idx);
        P_alloc(idx) = water_fill_alloc(gam, numel(idx)*P.Pt_W, 0.05);
        for ii = 1:numel(P.etaVals)
            w(idx,ii) = water_fill_alloc(gam, 1, P.etaVals(ii));
        end
    end
end
sinr_wfpa = P_alloc.*g_eff ./ N_eff;
tput_cepta = P.BW_Hz/P.UEsPerSec*log2(1+sinr_cepta)/1e6*(1-P.OH_total);
tput_wfpa = P.BW_Hz/P.UEsPerSec*log2(1+sinr_wfpa)/1e6*(1-P.OH_total);
tput_eta = zeros(N,numel(P.etaVals));
for ii = 1:numel(P.etaVals)
    tput_eta(:,ii) = P.BW_Hz*w(:,ii).*log2(1+sinr_cepta)/1e6*(1-P.OH_total);
end
R = table(repmat(snap,N,1), bsIdx, secIdx, x, y, g_eff, I_W, sinr_cepta, sinr_wfpa, ...
    10*log10(sinr_cepta), 10*log10(sinr_wfpa), tput_cepta, tput_wfpa, ...
    tput_eta(:,1), tput_eta(:,2), tput_eta(:,3), tput_eta(:,4), tput_eta(:,5), tput_eta(:,6), sweep_ms, ...
    'VariableNames', {'snapshot','bs','sector','x_m','y_m','g_eff','interference_W', ...
    'sinr_cepta_linear','sinr_wf_pa_linear','sinr_cepta_dB','sinr_wf_pa_dB', ...
    'tput_cepta_Mbps','tput_wf_pa_Mbps','tput_wf_ta_eta005_Mbps','tput_fc_wf_ta_eta020_Mbps', ...
    'tput_fc_wf_ta_eta035_Mbps','tput_fc_wf_ta_eta050_Mbps','tput_fc_wf_ta_eta070_Mbps', ...
    'tput_fc_wf_ta_eta100_Mbps','sweep_time_ms'});
end

function PLdB = path_loss(d_m, f_Hz)
f_GHz = f_Hz/1e9; d_m = max(d_m,1);
PLdB = 32.4 + 21*log10(d_m) + 20*log10(f_GHz);
end

function G = beam_gain(delta, HPBW, Gmax, Am)
G = Gmax - min(12*(delta./HPBW).^2, Am);
end

function ang = wrap180_local(ang)
ang = mod(ang+180,360)-180;
end

function a = water_fill_alloc(gamma,total,eta)
gamma = gamma(:); K = numel(gamma); a = zeros(K,1);
if K==0 || total<=0, return; end
equalShare = total/K; minInd = eta*equalShare; rem = total - K*minInd;
if rem <= 0, a(:) = equalShare; return; end
invG = 1./max(gamma,eps); active = true(K,1);
while true
    mu = (rem + sum(invG(active)))/sum(active);
    tmp = mu - invG;
    newActive = tmp > 0;
    if all(newActive == active)
        wf = max(tmp,0); s = sum(wf); if s>0, wf = wf*(rem/s); end
        a = minInd + wf; return;
    end
    active = newActive;
end
end

function S = snapshot_metrics(R, snap, P)
% Uses names without punctuation for MATLAB table compatibility.
vals = [metric_vec(R.sinr_cepta_dB,R.tput_cepta_Mbps,P), metric_vec(R.sinr_wf_pa_dB,R.tput_wf_pa_Mbps,P), ...
        metric_vec(R.sinr_cepta_dB,R.tput_wf_ta_eta005_Mbps,P), metric_vec(R.sinr_cepta_dB,R.tput_fc_wf_ta_eta050_Mbps,P)];
S = array2table([snap vals], 'VariableNames', {'snapshot', ...
    'CEPTA_AvgSINR_dB','CEPTA_AvgEffTput_Mbps','CEPTA_Coverage_pct','CEPTA_P5SINR_dB','CEPTA_JFI','CEPTA_AvgPHYTput_Mbps', ...
    'WFPA_AvgSINR_dB','WFPA_AvgEffTput_Mbps','WFPA_Coverage_pct','WFPA_P5SINR_dB','WFPA_JFI','WFPA_AvgPHYTput_Mbps', ...
    'WFTA_AvgSINR_dB','WFTA_AvgEffTput_Mbps','WFTA_Coverage_pct','WFTA_P5SINR_dB','WFTA_JFI','WFTA_AvgPHYTput_Mbps', ...
    'FCWFTA050_AvgSINR_dB','FCWFTA050_AvgEffTput_Mbps','FCWFTA050_Coverage_pct','FCWFTA050_P5SINR_dB','FCWFTA050_JFI','FCWFTA050_AvgPHYTput_Mbps'});
end

function v = metric_vec(sinr_dB,tput,P)
v = [mean(sinr_dB), mean(tput), 100*mean(sinr_dB>P.coverageThreshold_dB), prctile(sinr_dB,5), jain_fairness(tput), mean(tput)/(1-P.OH_total)];
end

function S = make_summary_table(T, sinr1, tput1, sinr2, tput2, name1, name2, P)
metrics = {'Avg. SINR (dB)'; 'Avg. Effective Throughput (Mbps/user)'; 'Coverage (SINR>3 dB) (% users)'; '5%-tile SINR (dB)'; 'JFI (Throughput)'; 'Avg. PHY Throughput (Mbps/user)'};
A = metric_vec(T.(sinr1), T.(tput1), P);
B = metric_vec(T.(sinr2), T.(tput2), P);
S = table(metrics, A(:), B(:), 'VariableNames', {'Parameter', name1, name2});
end

function CI = make_ci_table(S)
vars = S.Properties.VariableNames; vars = vars(2:end);
Scheme = {}; Metric = {}; Mean = []; StdDev = []; CI95 = [];
for i = 1:numel(vars)
    x = S.(vars{i});
    Scheme{end+1,1} = vars{i}; %#ok<AGROW>
    Metric{end+1,1} = vars{i}; %#ok<AGROW>
    Mean(end+1,1) = mean(x); StdDev(end+1,1) = std(x); CI95(end+1,1) = 1.96*std(x)/sqrt(numel(x)); %#ok<AGROW>
end
CI = table(Scheme, Metric, Mean, StdDev, CI95);
end

function C = make_convergence_table(T)
Scheme = {'CEPTA';'WF-PA';'WF-TA';'FC-WF-TA eta=0.50'};
cols = {'tput_cepta_Mbps','tput_wf_pa_Mbps','tput_wf_ta_eta005_Mbps','tput_fc_wf_ta_eta050_Mbps'};
T150 = zeros(4,1); T200 = zeros(4,1); Rel = zeros(4,1);
for i=1:4
    T150(i) = mean(T.(cols{i})(T.snapshot<=150)); T200(i) = mean(T.(cols{i})); Rel(i) = 100*(T200(i)-T150(i))/T150(i);
end
C = table(Scheme,T150,T200,Rel,'VariableNames',{'Scheme','Avg_eff_throughput_150_snapshots','Avg_eff_throughput_200_snapshots','Relative_change_percent'});
end

function J = jain_fairness(x)
x = x(:); x(~isfinite(x)) = 0; den = numel(x)*sum(x.^2);
if den <= 0, J = 0; else, J = (sum(x)^2)/den; end
end

function plot_hist2(x1,x2,l1,l2,xlab,ttl,fname)
figure('Color','w'); edges = linspace(min([x1;x2]),max([x1;x2]),41);
histogram(x1,edges,'FaceAlpha',0.55,'DisplayName',l1); hold on; histogram(x2,edges,'FaceAlpha',0.55,'DisplayName',l2);
grid on; xlabel(xlab); ylabel('Users'); title(ttl); legend('show','Location','best'); exportgraphics(gcf,fname,'Resolution',300); close(gcf);
end

function plot_cdf2(x1,x2,l1,l2,xlab,ttl,fname)
figure('Color','w'); x1=sort(x1); x2=sort(x2); y1=(1:numel(x1))'/numel(x1); y2=(1:numel(x2))'/numel(x2);
plot(x1,y1,'LineWidth',1.5,'DisplayName',l1); hold on; plot(x2,y2,'LineWidth',1.5,'DisplayName',l2);
grid on; xlabel(xlab); ylabel('CDF'); title(ttl); legend('show','Location','best'); exportgraphics(gcf,fname,'Resolution',300); close(gcf);
end
