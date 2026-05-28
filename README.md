# Water-Filling Optimization for Codebook Beam Sweeping: Reproducibility Package

This repository supports the manuscript **"Water-Filling Optimization for Codebook Beam Sweeping: Power Allocation versus Time-Resource Allocation"** submitted to IJIES.

The package contains the corrected 200-snapshot Monte Carlo workflow requested by the editor/reviewer, including the fixed UE distribution/load model, confidence intervals, convergence data, additional SINR percentiles, and raw CSV outputs for Tables 3-5 and Figs. 3-11.

## Main corrections implemented

1. **UE distribution is fixed by construction:** every Monte Carlo snapshot uses 7 BS sites × 3 sectors/site × 20 UEs/sector = 420 UEs. UEs are uniformly randomized **inside their assigned sector**, not associated afterward by strongest received power. Therefore, the realized sector load is exactly `N_j = 20` for every active sector in every snapshot.
2. **Activity factor is consistent with the UE model:** because `N_j = 20` and `N_ref = 30`, all active sectors use
   `rho_j = rho_idle + (rho_active-rho_idle)*min(1,N_j/N_ref) = 0.4833`.
3. **Monte Carlo reliability is reported:** 200 independent snapshots are used. The package reports 95% confidence intervals, snapshot-level standard deviations, and a 150-vs-200 snapshot convergence table.
4. **Fairness-constrained WF-TA notation is explicit:** `eta_T` is the normalized floor factor, and `tau_min = eta_T/K_s`. The row `eta_T = 1.00` is exactly CEPTA because all users receive `1/K_s`.
5. **Coverage threshold is fixed at 3 dB** in the simulation code, CSV files, and manuscript tables.

## Folder structure

```text
.
├── README.md
├── raw_csv/
│   ├── all_user_metrics_200snapshots.csv
│   ├── snapshot_level_metrics.csv
│   ├── table3_cepta_vs_wf_pa.csv
│   ├── table4_cepta_vs_wf_ta.csv
│   ├── table5_fairness_sweep.csv
│   ├── additional_sinr_percentiles_cepta_vs_wf_pa.csv
│   ├── confidence_intervals_200snapshots.csv
│   ├── monte_carlo_convergence_150_vs_200.csv
│   └── simulation_config.json
├── figures/
│   ├── fig1_scenario_layout.png
│   ├── fig2_codebook_beams.png
│   ├── fig3_sinr_hist_cepta_wfpa.png
│   ├── fig4_sinr_cdf_cepta_wfpa.png
│   ├── fig5_tput_hist_cepta_wfpa.png
│   ├── fig6_tput_cdf_cepta_wfpa.png
│   ├── fig7_sinr_hist_cepta_wfta.png
│   ├── fig8_sinr_cdf_cepta_wfta.png
│   ├── fig9_tput_hist_cepta_wfta.png
│   ├── fig10_tput_cdf_cepta_wfta.png
│   └── fig11_fairness_tradeoff_wfta.png
├── python_reference/
│   └── generate_results_reference.py
└── matlab/
    ├── main_reproduce_from_raw_csv.m
    └── main_run_monte_carlo.m
```

## Exact reproduction of the included manuscript outputs

The included raw CSV files and figures were generated with the Python reference implementation using seed `31001`.

```bash
cd python_reference
python generate_results_reference.py
```

The script writes all generated files to `../raw_csv` and `../figures`.

## MATLAB use

Two MATLAB entry points are included:

1. `main_reproduce_from_raw_csv.m` regenerates the manuscript tables and figures from the included raw CSV files. This reproduces the delivered tables/figures exactly from the archived data.
2. `main_run_monte_carlo.m` runs a MATLAB implementation of the 200-snapshot simulation logic. Because MATLAB and NumPy use different random-number streams, a fresh MATLAB run may not be byte-identical to the archived CSV files, but it implements the same corrected model, metrics, and allocation logic.

Run from the repository root:

```matlab
cd matlab
main_reproduce_from_raw_csv
main_run_monte_carlo
```

## Random seed policy

The archived Python run uses a single reproducible random seed, `31001`, for the entire Monte Carlo sequence. Each snapshot is generated sequentially from this stream. The fixed seed is used only for reproducibility; the statistics are reported over 200 independent randomized snapshots.

## Reported main numerical results from the archived 200-snapshot run

- CEPTA average effective throughput: 21.23 Mbps/user.
- WF-PA average effective throughput: 21.57 Mbps/user, corresponding to a 1.60% gain over CEPTA.
- WF-PA 5th-percentile SINR: -15.54 dB, compared with -2.53 dB for CEPTA.
- WF-TA average effective throughput: 32.66 Mbps/user, corresponding to a 53.84% gain over CEPTA.
- FC-WF-TA at `eta_T = 0.50`: 28.16 Mbps/user, corresponding to a 32.63% gain over CEPTA, with JFI = 0.4455.

## Software versions used for the archived outputs

- Python 3.x
- NumPy
- pandas
- matplotlib

MATLAB scripts are written in a conservative style compatible with standard MATLAB installations that support `readtable`, `writetable`, and local functions.
