*****************************************************************************
*** Figure 1: Vaccination coverage in Tyrolean districts
*****************************************************************************
clear all
capture log close
set more off

*** Set paths
cd "SET YOUR DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use `data'/BKZ_d_2021-07, replace

*****************************************************************************
*** Load district data & merge with vaccination data
*****************************************************************************
use daten/BKZ_d_2021-07.dta, clear

*** Merge population aged 0-16
merge m:1 bkz using ".. bezirke_einwohner", keepus(a_00_20)
drop _merge

keep if bl=="Tirol"

*** Merge Vaccination data
sort bkz date
merge 1:1 bkz date using "..tirol_V_BKZ_d_2021-07"
drop if _merge!=3
drop _merge

*** Cumulative vacciantions
xtset bkz date
tsfill, full
replace dose1=0 if dose1==.
replace dose2=0 if dose2==.
replace volli=0 if volli==.

sort bkz date
by bkz: g tt=_n
sort bkz tt
by bkz: g temp1=_N
sum temp1
local spell=r(max)*(-1)
rangestat (sum) dose1, int(tt `spell' 0) by(bkz)
rangestat (sum) dose2, int(tt `spell' 0) by(bkz)
rangestat (sum) volli, int(tt `spell' 0) by(bkz)

*** Vaccination per head
replace pop=pop-a_00_20				// correct for 0-16
g d1=dose1_sum/pop*100
g d2=dose2_sum/pop*100
g vo=volli_sum/pop*100

*** Collapse
g treat=(bkz==709)
collapse d1 d2 vo, by(treat date)

*** Timeline
local start=td(18feb2021)
local end=td(30jun2021)

local d1=td(10mar2021)				// 1 day before treatment 
local d1_end=td(16mar2021)
local d2=td(7apr2021)				// 1 day before treatment
local d2_end=td(11apr2021)

drop if date<`start' | date>`end'


*****************************************************************************
*** Figure
*****************************************************************************
sum date
#delimit
twoway scatteri 80 `d1' 80 `d1_end', recast(area) bc(gs11%1) fc(gs11%40) ||
	scatteri 80 `d2' 80 `d2_end', recast(area) bc(gs11%1) fc(gs11%40) ||
	line d1 date if treat==1, c(l) lw(0.5) lc(red*1.4) ||
	line d1 date if treat==0, c(l) lw(0.5) lc(midblue*1.4) ||
	line d2 date if treat==1, c(l) lw(0.5) lc(red*1.4) lp(dash) ||
	line d2 date if treat==0, c(l) lw(0.5) lc(midblue*1.4) lp(dash)
	ylabel(0(10)80,labs(2.5) angle(0) grid glc(gs14%15) glw(0.3))
    xlabel(`start'(14)`end' `d1' "{bf:d1}" `d2' "{bf:d2}", format(%td_DD.NN) labs(2) angle(0) grid glc(gs14%15) glw(0.3))
	title("", just(left) bexpand si(4) margin(b=4) span)		
	ytitle("Vaccination coverage, in %", place(12) orient(vertical) si(3) m(r=1))
	xtitle("", place(3) si(3) m(t=5))
	legend(order(3 "1st dose (d1) Schwaz" 4 "1st dose rest of Tyrol" 5 "2nd dose (d2) Schwaz" 6 "2nd dose rest of Tyrol") ring(1) pos(7) rows(1) bm("0 0 0 3") linegap(1) symy(3) symx(4) si(2.5) span region(color(none)))
	note("", span si(3) linegap(1) m(t=3)) 
	caption("Fig.1: Vaccination coverage of adult population in Schwaz and the rest of Tyrol", span m(t=4) si(3))
	plotregion(lcolor(gray*0.5) m(0)) 	graphregion(margin(2 5 2 2))
	saving(abb1_vacc, replace);
#delimit cr
graph export Fig1.png, as(png) replace

exit
