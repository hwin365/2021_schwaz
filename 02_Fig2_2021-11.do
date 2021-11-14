*****************************************************************************
*** Figure 2: SC Schwaz and synthetic Schwaz
*****************************************************************************
clear all
capture log close
set more off

cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use `data'/BKZ_d_2021-08, replace

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
drop if bezirk=="Rust(Stadt)" 			// drop district, data not reliable

*** Check numbe rof districts
egen temp1=group(bezirk)
sum temp1
drop temp1

*** Dependent variable
g y=nc

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
di as red `spell'

*** Cumulative daily infections
sort bkz tt
rangestat (sum) y if y!=., int(tt `spell' 0) by(bkz)

*** 7d-MA infections
tssmooth ma y7=y, w(6 1 0)
g inz=y7*7/pop*100000

*** Normalizing of y on day 1: cumulative infections & incidence
g temp1=y_sum if tt==1
egen temp2=max(temp1), by(bkz)
g temp3=y if tt==1
egen temp4=max(temp2), by(bkz)
g temp5=inz if tt==1
egen temp6=max(temp5), by(bkz)
replace y_sum=y_sum-temp2
drop temp*

**# Outcome variable (switch between cumulative infections & incidence)
g y_pc=y_sum/pop*100000
*g y_pc=inz

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

*** Descriptives (Table A1)
sum pop area scom
sum y_pc if tt==2
sum y_pc if tt==8
sum y_pc if tt==14
sum y_pc if tt==21

*****************************************************************************
*** SC
*****************************************************************************
replace area=area*100
tsset district tt
synth y_pc pop area scom y_pc(2) y_pc(8) y_pc(14) y_pc(`pretr'), tru(`tu') trp(`tr') ///
	keep(`data_temp'/sc_base, replace)
	
use `data_temp'/sc_base, clear
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

**# Calculate impact
gen diff_post_test = diff/_Y_treated*100 if _time == 155	// postreatment period (BM2)
sum diff_post_test

*** Schwaz and synthetic Schwaz
ren _Y_treated schwaz
ren _Y_synthetic synth_schwaz
keep _time schwaz synth_schwaz

*****************************************************************************
*** Figure 2
*****************************************************************************
gen temp1=_n
gen days=temp1-`tr'
drop temp1
local dose2=`d2'-`tr'

**# Ende of observsational period
drop if days>133

**# Treatment graph
sum days
#delimit
twoway line schwaz days, lp(solid) lw(0.5) lc(red*1.3) ||
	line synth_schwaz days, lw(0.5) lp(dash) lc(midblue*1.3) 
	xline(0, lp(shortdash) lw(0.3))
	xline(`dose2', lp(shortdash) lw(0.3))
	/*ylab(0(50)300, format(%8.0f) labs(2.2) angle(horizontal) grid glc(gs15) glw(0.05)) ysca(titlegap(1))*/
	ylab(0(500)2500, format(%8.0f) labs(2.2) angle(horizontal) grid glc(gs15) glw(0.05)) ysca(titlegap(1))
	xlab(`r(min)'(14)`r(max)' 0 "{bf:d1}" 28 "{bf:d2}", labs(2.0) angle(0)) xsca(titlegap(3))
	title("{bf:b}", just(left) bexpand si(4) margin(b=4) span)
	/*ytitle("7-day incidence (per 100,000)", place(12) orient(vertical) si(3))*/
	ytitle("Cumulative infections (per 100,000)", place(12) orient(vertical) si(3))
	xtitle("Days relative to vaccination campaign (1st dose: d1)", place(12) si(3)  m(t=1))
	legend(order(1 "Schwaz" 2 "Synthetic control group") ring(1) pos(7) rows(1) bm("0 0 0 2") linegap(1) region(color(none)) symy(3) symx(5) si(2.5))
	plotregion(lcolor(gray*0.00) m(0))
	saving(`output_graphs'/abb2a, replace)
	xsize(4) ysize(3);
#delimit cr

**# Figure 2: Combined graph (1st step: run code with line 79, 2nd step: comment out line 79 and insert line 80 and run code again)
#delimit
graph combine `output_graphs'/abb2a.gph `output_graphs'/abb2b.gph, cols(2)
	graphregion(color(white)) rows(1) xsize(4) ysize(2) iscale(1);
#delimit cr

*** Save
graph export Fig2.png", as(png) replace

exit
