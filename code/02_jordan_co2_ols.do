* Jordan: what drives CO2 emissions growth? OLS with diagnostics, 1991-2023

version 17
clear all
set more off
set scheme s1color
capture log close
log using "output/02_jordan_co2_ols.log", text replace

import delimited using "data/jordan_co2.csv", clear
tsset year


*------------------------------------------------------------------------------
* 1. Variables
*------------------------------------------------------------------------------
* Growth rates as 100 x log differences; budget balance as change in pp (it is negative every year)

foreach v in co2_mt exports_usd imports_usd energy_twh {
    generate ln_`v' = ln(`v')
    generate g_`v'  = 100 * D.ln_`v'
}
generate d_budget = D.budget_bal_gdp

label variable g_co2_mt      "CO2 emissions growth (%)"
label variable g_exports_usd "Exports growth (%)"
label variable g_imports_usd "Imports growth (%)"
label variable g_energy_twh  "Energy consumption growth (%)"
label variable d_budget      "Change in budget balance (pp of GDP)"

summarize g_co2_mt g_exports_usd g_imports_usd g_energy_twh d_budget
correlate g_co2_mt g_exports_usd g_imports_usd g_energy_twh d_budget

* Both series indexed to 1990 = 100 so they share one axis
generate co2_index    = 100 * co2_mt / co2_mt[1]
generate energy_index = 100 * energy_twh / energy_twh[1]
twoway (line co2_index year, lwidth(medthick)) (line energy_index year, lwidth(medthick) lpattern(dash)), ///
    title("Jordan: CO2 emissions and primary energy use (1990 = 100)", size(medium)) ///
    ytitle("Index, 1990 = 100") xtitle("") xlabel(1990(5)2020) ///
    legend(order(1 "CO2 emissions" 2 "Primary energy consumption") rows(1))
graph export "output/figures/jordan_co2_energy.png", replace width(1600)


*------------------------------------------------------------------------------
* 2. Unit roots
*------------------------------------------------------------------------------
* All stationary (ADF p < 0.001)
foreach v in g_co2_mt g_exports_usd g_imports_usd g_energy_twh d_budget {
    dfuller `v', lags(0)
}


*------------------------------------------------------------------------------
* 3. Baseline model
*------------------------------------------------------------------------------
regress g_co2_mt g_exports_usd g_imports_usd d_budget g_energy_twh
estimates store baseline

estat bgodfrey, lags(1 2)
estat hettest
estat archlm
estat ovtest
estat vif
predict resid_base, residuals
sktest resid_base

* RESET fails here (p = 0.019); the biggest residual is 2020


*------------------------------------------------------------------------------
* 4. Preferred model: 2020 dummy
*------------------------------------------------------------------------------
generate covid2020 = year == 2020
label variable covid2020 "2020 dummy"

regress g_co2_mt g_exports_usd g_imports_usd d_budget g_energy_twh covid2020
estimates store preferred

estat bgodfrey, lags(1 2)
estat hettest
estat archlm
estat ovtest
predict resid_pref, residuals
sktest resid_pref
estat sbcusum
graph export "output/figures/jordan_cusum.png", replace width(1400)

* Robustness: heteroskedasticity-robust standard errors
regress g_co2_mt g_exports_usd g_imports_usd d_budget g_energy_twh covid2020, vce(robust)
estimates store robust

estimates table baseline preferred robust, b(%9.3f) se(%9.3f) stats(N r2 r2_a) ///
    varlabel title("CO2 emissions growth, Jordan 1991-2023")

log close
