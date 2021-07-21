*****************************************************************************
*** Figure 4: Event study -- daily infections
*****************************************************************************
clear all
capture log close
set more off

cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use daten/tirol_GKZ_d_2021-07-12, clear			// date used for the ES

*** Keep Schwaz and neighboring districts
keep if (bezirk=="Kufstein" | bezirk=="Innsbruck-Land" | bezirk=="Schwaz")

*** Drop weeks after calendar week 26
drop if week>26

*****************************************************************************
**** Define treatment and control group
*****************************************************************************
*table gemeinde if bezirk=="Schwaz", c(m gkz)
*table gemeinde if bezirk=="Innsbruck-Land", c(m gkz)
*table gemeinde if bezirk=="Kufstein", c(m gkz)

*** Define TG/CG
local i=3		// 1: IL, 2: KU, 3: IL+KU
local j=1		// TG: 1 ... direct neighbor, 2 ... next neighbor

if `i'==1 {
	if `j'==1 {
		g treat=1 if gkz==70936 | gkz==70933 | gkz==70937 | gkz==70938 | gkz==70921 					
			// Vomp, Terfens, Weer, Weerberg (Pill)
		replace treat=0 if gkz==70301 | gkz==70311 | gkz==70309  | gkz==70322 | gkz==70323 | gkz==70367	
			// Absam, Gnadenwald, Fritzens, Kolsass, Kolsassberg (Wattens)
		}
	else {
		g treat=1 if gkz==70928 | gkz==70926 | gkz==70921 												
			// Stans, Schwaz, Pill
		replace treat=0 if gkz==70305  | gkz==70366 | gkz==70367 				
			// Baumkirchen, Wattenberg, Wattens
		}
	}
else if `i'==2 {
	if `j'==1 {
		g treat=1 if gkz==70930 | gkz==70939 | gkz==70904 | gkz==70925 | gkz==70905 | gkz==70917 | gkz==70907
			// Strass, Wiesing (Bruck, Schlitters, Buch, Jenbach, Eben)
		replace treat=0 if gkz==70517 | gkz==70522 | gkz==70512 | gkz==70506
			// Münster, Reith (Kramsach, Brixlegg)
		}
	else {
		g treat=1 if gkz==70907 | gkz==70917 | gkz==70905 | gkz==70925 | gkz==70904 					
			// Eben, Jenbach, Buch, Schlitters, Bruck
		replace treat=0 if gkz==70504 | gkz==70512 | gkz==70521 | gkz==70520 | gkz==70501 | gkz==70506 	
			// Brandenberg, Kramsach, Rattenberg, Radfeld, Brixlegg, Alpbach
		}
	}
else {
	if `j'==1 {
		g treat=1 if gkz==70936 | gkz==70933 | gkz==70937 | gkz==70938 | gkz==70921 | gkz==70930 | gkz==70939 | gkz==70904 | gkz==70925 | gkz==70905 | gkz==70917 | gkz==70907	
			// Vomp, Terfens, Weer, Weerberg (Pill) -- Strass, Wiesing (Bruck, Schlitters, Buch, Jenbach, Eben)
		replace treat=0 if gkz==70301 | gkz==70311 | gkz==70309 | gkz==70322 | gkz==70323 | gkz==70367 | gkz==70517 | gkz==70522 | gkz==70512 | gkz==70506
			// Absam, Fritzens, Gnadenwald, Kolsass, Kolsassberg -- Münster, Reith (Kramsach, Brixlegg) 
		}
	else {
		g treat=1 if gkz==70928 | gkz==70926 | gkz==70921 | gkz==70907 | gkz==70917 | gkz==70905 | gkz==70925 | gkz==70904
			// Stans, Schwaz, Pill -- Eben, Jenbach, Buch, Schlitters, Bruck
		replace treat=0 if gkz==70305 | gkz==70366 | gkz==70367 | gkz==70504 | gkz==70512 | gkz==70521 | gkz==70520 | gkz==70501 | gkz==70506
			// Hall, Mils, Baumkirchen, Wattenberg, Wattens -- Brandenberg, Kramsach, Rattenberg, Radfeld, Brixlegg, Alpbach
		}
}

*** All municipalities in Schwaz/neighb. districts as TG
*drop treat
replace treat=1 if bezirk=="Schwaz"
*replace treat=0 if bezirk=="Innsbruck-Land" | bezirk=="Kufstein"

*****************************************************************************
**** Timeline
*****************************************************************************
local startES=td(18jan2021)
sum date
local endES=`r(max)'

*** Define 1st week and set counter
g temp1=week if date==`startES'
egen temp2=max(temp1)
sum temp2
local startweek=r(max)
di as red `startweek'
drop temp*

g time=week-`startweek'
drop if time<0 | year==2020

*** Event dates
local vacc1_start=td(11mar2021)
local vacc1_ende=td(16mar2021)
local vacc2_start=td(8apr2021)
local vacc2_ende=td(11apr2021)

*** Mark event & eventweek
local event=`vacc1_start'
g temp1=time if date==`event'
egen temp2=max(temp1)
sum temp2
local eventweek=r(max)
di as red `eventweek'
drop temp*

*** Mark end of ES
g temp1=time if date==`endES'
egen temp2=max(temp1)
sum temp2
local endweek=r(max)
di as red `endweek'
drop temp*

*****************************************************************************
**** Dependent variable
*****************************************************************************
keep if treat== 0 | treat== 1
egen id=group(gkz)
keep id treat date pop gkz week time nc_ages nc_goeg nd_goeg nc_alpha nc_alpha1 nc_beta nc_gamma

*** Switch between nc (new cases: nc_goeg), nc_alpha+nc_alpha1 & nc_beta
g nc=nc_alpha+nc_alpha1+nc_beta

*** 7-day MA per 100.000
xtset gkz date
tssmooth ma nc7=nc, w(6 1 0)
g nc_av=nc7/pop*100000

*** Pre-treatment infections
preserve
collapse nc_av pop, by(treat date)
sum nc_av if treat==1 & date<td(11mar2021)
restore

*****************************************************************************
**** Prepare ES
*****************************************************************************
collapse nc_av pop treat time, by(date gkz)
sort treat date

*** Set number of days that will be used for one dummy
local days=7
sum date
local maxdate=`r(max)'

*** I is the number of x days-period between lockdown and the end of the sample
local I=ceil((`maxdate'-`startES')/`days')
di `I'

*** Now create a dummy for each x-day period after the lockdown
forval i=1/`I' {
	gen time`i'=0
	gen temp1=`startES'+(`i'-1)*`days'
	gen temp2=`startES'+`i'*`days'
	replace time`i'=1 if date>=temp1 & date<temp2
	drop temp*
}

*** Interact the periods with the dummy for Schwaz
forval i=1/`I' {
gen intschwaz`i'=time`i'*treat
}

*** Drop the variables for the second period which will serve as the omitted period in the regressions
drop time`eventweek' intschwaz`eventweek'
gen sample=date>=`startES' & date<=`endES'
sort treat date

*****************************************************************************
**** Regression & Results Matrix
*****************************************************************************
matrix results = J(`I',4,.)
matrix results[1,4] = `startES'
local col1 = 1
local col2 = 2
local col3 = 3
local col4 = 4
local row = 1

*** Regressions
egen id=group(gkz)
xtset id date
*xtreg nc_av ints* time* if sample, fe vce(cl gkz)
reghdfe nc_av ints* if sample, a(id time) vce(cl gkz)		// alternative
drop id

*** Matrix of coefficients
local T1=`eventweek'-1
forval i == 1/`T1' {
	mat results[`row',`col1'] = _b[intschwaz`i']
	mat results[`row',`col2'] = _b[intschwaz`i']-1.96*_se[intschwaz`i']
	mat results[`row',`col3'] = _b[intschwaz`i']+1.96*_se[intschwaz`i']
	mat results[`row',`col4'] = `startES'+7*(`i'-1)
	local ++row
}
mat results[`eventweek',1] = 0
mat results[`eventweek',2] = 0
mat results[`eventweek',3] = 0
mat results[`eventweek',4] = `event'

local T2=`eventweek'+1
local row = `eventweek'+1
forval i == `T2'/`endweek' {
	mat results[`row',`col1'] = _b[intschwaz`i']
	mat results[`row',`col2'] = _b[intschwaz`i']-1.96*_se[intschwaz`i']
	mat results[`row',`col3'] = _b[intschwaz`i']+1.96*_se[intschwaz`i']
	mat results[`row',`col4'] = `startES'+7*(`i'-1)
	local ++row
}
matrix colnames results= schwaz schwaz_lb schwaz_ub date
mat li results, f(%8.2f)	

*****************************************************************************
**** ES-Figure
*****************************************************************************
preserve
clear
svmat results, names(col)

*** Time to event
g temp1=_n
g tte=temp1-`eventweek'

*** Restrict graph to week 16 after event
drop if tte>16

sum tte
#delimit
twoway scatter schwaz tte, m(o) mc(red*1.4) msiz(1.7) ||  
	rcap schwaz_ub schwaz_lb tte, lw(0.2) lc(red*1.4) msiz(0.7)
	yline(0, lw(0.3) lc(gs8))
	xline(0, lp(dash) lw(0.3))
	xline(4, lp(dash) lw(0.3))
	ylabel(-50(10)30,labs(2.5) angle(0) grid glc(gs14%15) glw(0.3))
    xlabel(`r(min)'(1)`r(max)' 0 "{bf:d1}" 4 "{bf:d2}", labs(2) angle(0) grid glc(gs14%15) glw(0.3)) 
	title("{bf:b}", just(left) bexpand si(4) margin(b=4) span)
	ytitle("Difference in 7-day moving average per 100,000", place(12) orient(vertical) si(3) m(r=1))
	xtitle("Weeks relative to vaccination campaign (1st dose: d1)", place(12) si(3) m(t=4))
	legend(order(1 "Point estimate" 2 "95% -- CI") ring(0) pos(1) rows(1) bm("3 0 2 0") linegap(1) region(color(none)) symy(3) symx(5) si(2.5))
	note("", span si(3) linegap(1) m(t=3)) 
	plotregion(lcolor(gray*0.5) m(l=1)) graphregion(margin(2 5 2 2))
	saving(abb5_mutant, replace);
#delimit cr
restore

*****************************************************************************
**** 2x2 DD
*****************************************************************************
g ints=(date>`event' & treat==1)
egen id=group(gkz), label

*** Absolute effect
*g post=(date>`event')
g post=(date>td(25mar2021))
reg nc_av i.treat##i.post if sample, vce(cl id)

*** Semi-elasticity
g y=ln(nc_av+(nc_av^2+1)^0.5)			// IHS-transf. to account for zeros
reg y i.treat##i.post if sample, vce(cl id)
di as red (exp(_coef[1.treat#1.post])-1)*100

*** Event window after March 25
g post1=(date>td(25mar2021))
reg y i.treat##i.post1 if sample, vce(cl id)
di as red (exp(_coef[1.treat#1.post1])-1)*100

*****************************************************************************
**** Figure 5: Combined graph 
**** First, letzt code run with nc_goeg in line 135, then change to nc_alpha+nc_alpha1+nc_beta
*****************************************************************************
#delimit
graph combine abb5_allinf.gph abb5_mutant.gph, 
	caption("Fig.5: Daily infections of SARS-CoV-2 ({bf:a:} all infections) and its VoCs ({bf:b:} B.1.351 and B.1.1.7/E484K) in Schwaz and the neighbouring municipalities", si(2.8) m(t=2))
	graphregion(color(white)) rows(1) xsize(4) ysize(2) iscale(0.9);
#delimit cr
graph export "`output_graphs'/Fig5.png", as(png) replace

exit
