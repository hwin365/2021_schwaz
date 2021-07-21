*****************************************************************************
*** Figure 4: SC Hospitalizations - districts, weekly data
*****************************************************************************
clear all
capture log close
set more off

cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use daten/BKZ_w_2021-07, clear	// data used for SC

drop if yr==2020

xtset bkz kw
sort bkz kw
by bkz: g tt=_n

*****************************************************************************
*** Timeline 
*****************************************************************************
local start=6					
drop if kw<`start'

local d1_start=10			// 11.3. corresponds to calendar week 10
local d1_ende=11
local d2_start=14			// dose 2
local d2_ende=14

*****************************************************************************
*** Dependent variable: Hospitalizations per 100,000
*** norm: general hospitalizations
*** icu: ICUs
*****************************************************************************
drop if bezirk=="Rust(Stadt)" 			// drop district, data are unreliable

*** Switch between normal and ICU cap.
g y=norm
drop if kw>21

*** Spell
drop tt
sort bkz kw
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
g d1=(kw==`d1_start')
sort bkz kw
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

g dose2=tt if kw==`d2_start'
sum dose2
local d2=r(max)

*****************************************************************************
*** SC
*****************************************************************************
tsset district tt
synth y_pc pop area scom y_pc(2) y_pc(3) y_pc(5), tru(`tu') trp(`tr') ///
	keep(hosp, replace)

use hosp, clear

*** Schwaz and synthetic Schwaz
ren _Y_treated schwaz
ren _Y_synthetic synth_schwaz
keep _time schwaz synth_schwaz

*****************************************************************************
*** Figure
*****************************************************************************
drop if schwaz==.
gen temp1=_n
gen days=temp1-`tr'
drop temp1
local dose2=`d2'-`tr'

sum days
#delimit
twoway line schwaz days, lp(solid) lw(0.5) lc(red*1.3) ||
	line synth_schwaz days, lw(0.5) lp(dash) lc(midblue*1.3) 
	xline(0, lp(shortdash) lw(0.3))
	xline(`dose2', lp(shortdash) lw(0.3))
ylab(0(25)125, format(%8.0f) labs(2.2) angle(horizontal) grid glc(gs13%40) glw(0.05)) ysca(titlegap(1))
xlab(`r(min)'(1)`r(max)' 0 "{bf: d1}" 4 "{bf: d2}", labs(2.0) angle(0) grid glc(gs13%40) glw(0.05)) xsca(titlegap(3))
title("{bf:a}", just(left) bexpand si(4) margin(b=4) span)				 
ytitle("Hospital admissions per 100,000", place(12) orient(vertical) si(2.5)) 
xtitle("Weeks relative to vaccination campaign (1st dose: d1)", place(12) si(2.5) m(t=1))
legend(order(1 "Schwaz" 2 "Synthetic Schwaz") ring(1) pos(7) rows(1) bm("0 0 0 2") linegap(1) region(color(none)) symy(3) symx(5) si(2.5))
plotregion(lcolor(gray*0.00) m(0))
xsize(4) ysize(3)
saving(abb4_norm, replace);
#delimit cr

*** Graph combine: First run code with "g y=norm" in line 47, and then change to g "y=icu"
#delimit
graph combine abb4_norm.gph abb4_icu.gph, 
	caption("Fig.4: Hospital ({bf:a}) and ICU ({bf:b}) admissions in Schwaz versus synthetic control group")
	graphregion(color(white)) rows(1) xsize(4) ysize(2) iscale(1);
#delimit cr
graph export Fig4.png, as(png) replace
restore

exit