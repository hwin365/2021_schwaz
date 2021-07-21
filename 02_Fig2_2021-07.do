*****************************************************************************
*** Figure 2: SC Schwaz and synthetic Schwaz
*****************************************************************************
clear all
capture log close
set more off

*** Set paths
cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use daten/BKZ_d_2021-07.dta, clear	// data used for SC

xtset bkz date
sort bkz date
by bkz: g tt=_n

*****************************************************************************
*** Timeline
*****************************************************************************
local start=td(18feb2021)
drop if date<`start'

local d1_start=td(11mar2021)
local d1_end=td(16mar2021)
local d2_start=td(08apr2021)
local d2_end=td(11apr2021)

*****************************************************************************
*** Dependent variable: cumulative infections per capita in 100,000
*****************************************************************************
drop if bezirk=="Rust(Stadt)" 		// drop district, data are unreliable

*** Spell
drop tt
sort bkz date
bys bkz: g tt=_n
bys bkz: g T=_N
sum T
local T=r(max)
drop T
di as red `T'

local spell=`T'*(-1)
di as red `dura'

*** Dependent variable
g y=nc

*** Cumulative daily infections
sort bkz tt
by bkz: g temp1=_N
sum temp1
local spell=r(max)*(-1)
rangestat (sum) y if y!=., int(tt `spell' 0) by(bkz)
drop temp1

*** Normalization of y on day 1
g temp1=y_sum if tt==1
egen temp2=max(temp1), by(bkz)
replace y_sum=y_sum-temp2
drop temp*

*** y per capita
g y_pc=y_sum/pop*100000

*****************************************************************************
*** Prepare SC
*****************************************************************************
*** Treatment date
g d1=(date==`d1_start')
sort bkz date
bysort bkz: replace d1=1 if d1[_n-1]==1

*** Treatment unit
encode bezirk, g(district)
label list district
g tu=district if bezirk=="Schwaz"
sum tu
local tu=r(max)
drop tu

*** SC-dates
g start=`start'
g dose1=`d1_start'
g treat=dose1-start+1
sum treat
local tr=r(max)
di `tr'
local pretr=`tr'-1

g dose2=tt if date==`d2_start'
sum dose2
local d2=r(max)

*** Descriptives
sum pop area scom
sum y_pc if tt==2
sum y_pc if tt==8
sum y_pc if tt==14
sum y_pc if tt==21

*****************************************************************************
*** SC
*****************************************************************************
tsset district tt
synth y_pc pop area scom y_pc(2) y_pc(8) y_pc(14) y_pc(`pretr'), tru(`tu') trp(`tr') ///
	keep(sc_base, replace)

use sc_base, clear
gen diff = _Y_treated - _Y_synthetic 
drop _Co_Number _W_Weight 

*** Calculate RMSPE-ratio
gen diff_pre = diff^2 if _time < `tr'
egen pre_MSPE = total(diff_pre)
replace pre_MSPE = pre_MSPE/(`tr'-1)
gen RMSPE_pre = sqrt(pre_MSPE)
gen diff_post = diff^2 if _time >= `tr'
egen post_MSPE = total(diff_post)
replace post_MSPE = post_MSPE/`T'
gen RMSPE_post = sqrt(post_MSPE)
gen ratio = RMSPE_post/RMSPE_pre
replace ratio = 0 if ratio==.
sum ratio

*** Calculate impact
gen diff_post_test = diff/_Y_treated*100 if _time == 112	// calculate impact; ACHTUNG: zeitliche Einschränkung
sum diff_post_test

*** Schwaz and synthetic Schwaz
ren _Y_treated schwaz
ren _Y_synthetic synth_schwaz
keep _time schwaz synth_schwaz

*****************************************************************************
*** Figure
*****************************************************************************
gen temp1=_n
gen days=temp1-`tr'
drop temp1
local dose2=`d2'-`tr'

*** Period end for paper
drop if days>112

*** Post-treatment period
sum days
#delimit
twoway line schwaz days, lp(solid) lw(0.5) lc(red*1.3) ||
	line synth_schwaz days, lw(0.5) lp(dash) lc(midblue*1.3) 
	xline(0, lp(shortdash) lw(0.3))
	xline(`dose2', lp(shortdash) lw(0.3))
	ylab(, format(%8.0f) labs(2.2) angle(horizontal) grid glc(gs13%40) glw(0.05)) ysca(titlegap(1))
	xlab(`r(min)'(14)`r(max)' 0 "{bf:d1}" 28 "{bf:d2}", labs(2.0) angle(0) grid glc(gs13%40) glw(0.05)) xsca(titlegap(3))
	title("{bf:a}", just(left) bexpand si(4) margin(b=4) span)
	ytitle("Cumulative infections per 100,000", place(12) orient(vertical) si(2.5))
	xtitle("Days relative to vaccination campaign (1st dose: d1)", place(12) si(2.5)  m(t=1))
	legend(order(1 "Schwaz" 2 "Synthetic control group") ring(1) pos(7) rows(1) bm("0 0 0 2") linegap(1) region(color(none)) symy(3) symx(5) si(2.5))
	plotregion(lcolor(gray*0.00) m(0))
	xsize(4) ysize(3)
saving(abb2_scpost, replace);
#delimit cr

*** Pre-treatment period
sum days
#delimit
twoway line schwaz days if days<=0, lp(solid) lw(0.5) lc(red*1.3) ||
	line synth_schwaz days if days<=0, lw(0.5) lp(dash) lc(midblue*1.3)
	xline(0, lp(shortdash) lw(0.3))
	ylab(0(100)520, format(%8.0f) labs(2.2) angle(horizontal) grid glc(gs13%40) glw(0.05)) ysca(titlegap(1))
	xlab(`r(min)'(7)0 0 "{bf:d1}", labs(2.0) angle(0) grid glc(gs13%40) glw(0.05)) xsca(titlegap(3))
	title("{bf:b}", just(left) bexpand si(4) margin(b=4) span)
	ytitle("Cumulative infections per 100,000", place(12) orient(vertical) si(2.5))
	xtitle("Days relative to vaccination campaign (1st dose: d1)", place(12) si(2.5) m(t=1))
	legend(order(1 "Schwaz" 2 "Synthetic control group") ring(1) pos(7) rows(1) bm("0 0 0 2") linegap(1) region(color(none)) symy(3) symx(5) si(2.5))
	plotregion(lcolor(gray*0.00) m(0))
	xsize(4) ysize(3)
	saving(abb2_scpre, replace);
#delimit cr

*** Figure 2: Combined graph
#delimit
graph combine abb2_scpost.gph abb2_scpre.gph, 
	caption("Fig.2: Cumulative daily infections of Schwaz versus synthetic control group ({bf:a:} after campaign; {bf:b:} before campaign)", si(3))
	graphregion(color(white)) rows(1) xsize(4) ysize(2) iscale(1);
#delimit cr
graph export Fig2.png", as(png) replace

exit
