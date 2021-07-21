*****************************************************************************
*** Figure 3: SC by age group
*****************************************************************************
clear all
capture log close
set more off

cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
forval i = 1/6 {
use `data_temp'/inf_BKZ_agek`i', clear		// load data for each age-group

xtset bkz date
sort bkz date
by bkz: g tt=_n

ren pop_`i' pop

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
*** Dependent variable: cumulative infections per 100000
*****************************************************************************
drop if bl=="Wien" 						// drop whole district of Vienna
drop if bezirk=="Rust(Stadt)" 			// drop district, data are unreliable

drop tt
sort bkz date
bys bkz: g tt=_n
bys bkz: g T=_N
sum T
local T=r(max)
drop T

*** Summing up infections
egen temp1=max(tt)
sum temp1
local spell=r(max)*(-1)
rangestat (sum) nc, int(tt `spell' 0) by(bkz)
ren nc_sum sc
drop temp1

*** Normalizing on day 1
g temp1=sc if tt==1
egen temp2=max(temp1), by(bkz)
replace sc=sc-temp2
drop temp*

*** Dependent variable
sort bkz date
g sc_pc=sc/pop*100000

*****************************************************************************
*** SC
*****************************************************************************
g d1=(date==`d1_start')
sort bkz date
bysort bkz: replace d1=1 if d1[_n-1]==1

*** Treatment unit
encode bezirk, g(district)
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

*** SC
tsset district tt
synth sc_pc pop area scom sc_pc(2) sc_pc(8) sc_pc(14) sc_pc(`pretr'), tru(`tu') trp(`tr') ///
	keep(scoutp_age, replace)

*** Age-specific differences between Schwaz and synth. Schwaz
use scoutp_age, clear
gen diff`i' = (_Y_treated - _Y_synthetic)*(-1)
drop _Co_Number _W_Weight _Y_synthetic

gen diff_post_test = diff/_Y_treated*100 if _time == 112					// calculate impact
sum diff_post_test

ren _time time
save diff`i', replace
}

use diff1, clear
sort time
merge 1:1 time using diff2
drop _merge
merge 1:1 time using diff3
drop _merge
merge 1:1 time using diff4
drop _merge
merge 1:1 time using diff5
drop _merge
merge 1:1 time using diff6
drop _merge

*****************************************************************************
*** Figure
*****************************************************************************
replace time=time-`tr'
local dose2=`d2'-`tr'

*** Period end for paper
drop if time>112

sum time
#delimit
twoway // line diff1 time, lp(dash) lw(0.5) lc(teal%20) ||
	line diff2 time, lw(0.5) lc(gold*1.0) ||
	line diff3 time, lw(0.5) lc(orange*1.0) ||
	line diff4 time, lw(0.5) lc(blue*0.5) ||
	line diff5 time, lw(0.5) lc(purple*0.7) ||
	line diff6 time, lw(0.5) lc(black) 
	yline(0, lc(gs12) lw(0.3))
	xline(0, lp(shortdash) lw(0.3))
	xline(`dose2', lp(shortdash) lw(0.3))
ylab(0(250)1250, format(%8.0f) labs(2.2) angle(horizontal) grid glc(gs13%40) glw(0.05)) ysca(titlegap(1))
xlab(`r(min)'(14)`r(max)' 0 "{bf:d1}" 28 "{bf:d2}", labs(2.0) angle(0) grid glc(gs13%40) glw(0.05)) xsca(titlegap(3))
title("", si(4) margin(b=4) span)
ytitle("Difference in cumulative daily infections per 100,000", place(12) orient(vertical) si(2.5))
xtitle("Days relative to vaccination campaign (1st dose: d1)", place(12) si(2.5) m(t=1))
legend(order(1 "age 20-34" 2 "age 35-49" 3 "age 50-64" 4 "age 65-79" 5 "age >80") ring(1) pos(7) rows(1) bm("0 0 0 2") linegap(1) region(color(none)) symy(1) symx(5) si(2.5))
caption("Fig.3: Difference in cumulative daily infections by age group between synthetic control group and Schwaz", span m(t=4) si(2.8))
plotregion(lcolor(gray*0.00) m(0))
xsize(4) ysize(3);
#delimit cr
graph export Fig3.png, as(png) replace

exit