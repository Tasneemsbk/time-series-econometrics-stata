* UK macro: unit roots, cointegration, VAR, Granger causality (World Bank data, 1970-2025)

version 17
clear all
set more off
set scheme s1color
capture log close
log using "output/01_uk_var.log", text replace

import delimited using "data/uk_macro.csv", clear
tsset year

label variable gdp_growth  "Real GDP growth (%)"
label variable exch_rate   "GBP per USD"
label variable exports_gdp "Exports (% of GDP)"
label variable imports_gdp "Imports (% of GDP)"

summarize gdp_growth exch_rate exports_gdp imports_gdp

* The four series over time
foreach v in gdp_growth exch_rate exports_gdp imports_gdp {
    tsline `v', name(`v', replace) nodraw title("`: variable label `v''", size(medium)) ///
        xtitle("") ytitle("") xlabel(1970(10)2020)
}
graph combine gdp_growth exch_rate exports_gdp imports_gdp, cols(2) ///
    title("UK macroeconomic series, 1970-2025")
graph export "output/figures/uk_series.png", replace width(1600)


*------------------------------------------------------------------------------
* 1. Unit roots (augmented Dickey-Fuller, one lag)
*------------------------------------------------------------------------------
* GDP growth is I(0); the other three are I(1)

foreach v in gdp_growth exch_rate exports_gdp imports_gdp {
    dfuller `v', lags(1)
    dfuller `v', lags(1) trend
    dfuller D.`v', lags(1)
}


*------------------------------------------------------------------------------
* 2. Cointegration among the I(1) series (Johansen trace test)
*------------------------------------------------------------------------------
* Rank 0 not rejected at 5% (trace 29.44 vs 29.68), so no VECM

varsoc exch_rate exports_gdp imports_gdp, maxlag(4)
vecrank exch_rate exports_gdp imports_gdp, lags(2) trend(constant)


*------------------------------------------------------------------------------
* 3. VAR in stationary form
*------------------------------------------------------------------------------
* GDP growth in levels, others differenced; 2020 and 2021 as dummies; 2 lags

generate d_exch    = D.exch_rate
generate d_exports = D.exports_gdp
generate d_imports = D.imports_gdp
label variable d_exch    "Change in GBP per USD"
label variable d_exports "Change in exports (% GDP)"
label variable d_imports "Change in imports (% GDP)"

generate covid2020 = year == 2020
generate covid2021 = year == 2021

varsoc gdp_growth d_exports d_imports d_exch, maxlag(4) exog(covid2020 covid2021)

var gdp_growth d_exports d_imports d_exch, lags(1/2) exog(covid2020 covid2021)


*------------------------------------------------------------------------------
* 4. Granger causality
*------------------------------------------------------------------------------
vargranger


*------------------------------------------------------------------------------
* 5. Diagnostics
*------------------------------------------------------------------------------
* LM autocorrelation, normality, stability
varlmar, mlag(2)
varnorm, jbera
varstable, graph
graph export "output/figures/uk_var_stability.png", replace width(1200)


*------------------------------------------------------------------------------
* 6. Impulse responses
*------------------------------------------------------------------------------
* Orthogonalised IRFs, Cholesky order as listed in the VAR
irf create uk_var, set("output/uk_irf", replace) step(8)
irf table oirf, impulse(gdp_growth) response(d_exports d_imports d_exch) noci step(4)

* Plot four responses from the saved IRF file
preserve
use "output/uk_irf.irf", clear
generate lo = oirf - 1.96 * stdoirf
generate hi = oirf + 1.96 * stdoirf
local i 0
foreach pair in "gdp_growth d_exports GDP growth shock: exports (% GDP)" ///
                "gdp_growth d_imports GDP growth shock: imports (% GDP)" ///
                "gdp_growth d_exch GDP growth shock: GBP per USD" ///
                "d_exch d_imports Exchange rate shock: imports (% GDP)" {
    local ++i
    gettoken imp rest : pair
    gettoken res ttl  : rest
    twoway (rarea lo hi step if impulse == "`imp'" & response == "`res'", color(gs13)) ///
           (line oirf step if impulse == "`imp'" & response == "`res'", lwidth(medthick)), ///
        yline(0, lcolor(gs8)) legend(off) xtitle("Years after shock") ytitle("") ///
        title("`ttl'", size(medium)) name(irf`i', replace) nodraw
}
graph combine irf1 irf2 irf3 irf4, cols(2) ///
    title("Orthogonalised impulse responses with 95% confidence bands", size(medium))
restore
graph export "output/figures/uk_irf.png", replace width(1600)

log close
