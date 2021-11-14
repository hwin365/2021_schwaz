*****************************************************************************
*** Figure 4: Event study -- weekly infections
*****************************************************************************
clear all
capture log close
set more off

cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use daten/tirol_GKZ_w_2021-09-15.dta, clear

*** Keep Schwaz and neighboring districts
keep if (bezirk=="Kufstein" | bezirk=="Innsbruck-Land" | bezirk=="Schwaz")

*** Drop weeks after calendar week 29
drop if week>29

*****************************************************************************
**** Define treatment and control group
*****************************************************************************
*table gemeinde if bezirk=="Schwaz", stat(m gkz)
*table gemeinde if bezirk=="Innsbruck-Land", stat(m gkz)
*table gemeinde if bezirk=="Kufstein", stat(m gkz)

*** Define TG/CG
local i=3		// 1: IL, 2: KU, 3: IL+KU
local j=1		// TG: 1 ... direct neighbour, 2 ... next neighbour

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
table treat, stat(count gkz)

*****************************************************************************
**** Timeline
*****************************************************************************
local startES=3					// Start of ES -> KW3

*** Counter
g time=week-`startES'
drop if time<0

*** Event dates
local vacc1_start=10			// Dose 1, 11.-16.3. --> CW10/11
local vacc1_ende=11				
local vacc2_start=14			// Dose 2, 8.-11.4. --> CW14
local vacc2_ende=14				

*** Mark event
local event=`vacc1_start'-`startES'
di as red `event'
local dose2=`vacc2_start'-`startES'
di as red `dose2'

*** Mark end of ES
sum time
local endES=`r(max)'
di as red `endES'

*****************************************************************************
**** Dependent variable
*****************************************************************************
keep if treat== 0 | treat== 1
keep gkz year week time treat nc_ages nc_goeg nc_alpha nc_alpha1 nc_beta nc_gamma nc_delta norm icu pop

*** Only for cases: Switch between GOEG_ and AGES-data
*g nc=nc_goeg
g nc=nc_alpha+nc_alpha1+nc_beta+nc_delta

*** 7-day MA & incidence
xtset gkz time
g nc_av=(nc)/pop*100000					
g norm_av=(norm)/pop*100000
g icu_av=(icu)/pop*100000

*** Hospitalization: Share of zero entries
g icu_NULL=(icu_av==0)
g norm_NULL=(norm_av==0)
sum icu_NULL norm_NULL
drop icu_NULL norm_NULL

*****************************************************************************
**** Prepare ES
*****************************************************************************
collapse nc_av norm_av icu_av pop treat week icu norm, by(gkz time)
sort treat time

*** Switch between nc_av, hospitalisation (norm_av) & ICU (icu_av)
g y=nc_av						

*** Pre-treatment outcome variable
preserve
collapse (mean) y norm_av icu_av icu norm, by(treat week)
drop if week>21
sum y if treat==1 & week<`event'
*table week treat, c(sum norm)
*table week treat, c(sum icu)
restore

*** Interact the periods with the dummy for Schwaz
tab time, g(ew)
forval i=1/`endES' {
	gen intschwaz`i'=ew`i'*treat
}

*** Drop the variables for the second period which will serve as the omitted period in the regressions
drop ew`event' intschwaz`event'
gen sample=time>=0 & time<=`endES'
sort treat time

*****************************************************************************
**** Regression & Results Matrix
*****************************************************************************
matrix results = J(`endES',4,.)
mat results[1,4] = `startES'
local col1 = 1
local col3 = 3
local col2 = 2
local col4 = 4
local row = 1

*** Regressions
egen id=group(gkz)
xtset id time
xtreg y ew* ints* time* if sample, fe vce(cl gkz)

*** Matrix of coefficients
local T1=`event'-1
forval i == 1/`T1' {
	mat results[`row',`col1'] = _b[intschwaz`i']
	mat results[`row',`col2'] = _b[intschwaz`i']-1.96*_se[intschwaz`i']
	mat results[`row',`col3'] = _b[intschwaz`i']+1.96*_se[intschwaz`i']
	mat results[`row',`col4'] = `i'
	local ++row
}
mat results[`event',1] = 0
mat results[`event',2] = 0
mat results[`event',3] = 0
mat results[`event',4] = `event'

local T2=`event'+1
local row = `event'+1
forval i == `T2'/`endES' {
	mat results[`row',`col1'] = _b[intschwaz`i']
	mat results[`row',`col2'] = _b[intschwaz`i']-1.96*_se[intschwaz`i']
	mat results[`row',`col3'] = _b[intschwaz`i']+1.96*_se[intschwaz`i']
	mat results[`row',`col4'] = `i'
	local ++row
}
matrix colnames results= schwaz schwaz_lb schwaz_ub time
mat li results, f(%8.2f)	

*****************************************************************************
**** ES-Figure 
*****************************************************************************
preserve
clear
svmat results, names(col)

*** Time to event
g tte=time-`event'
sum tte

**# Restrict graph to week 16 after event
drop if tte>19

sum tte
#delimit
twoway //line schwaz dweek, lw(0.5) lc(red*1.4) ||
	scatter schwaz tte, m(o) mc(red*1.4) msiz(1.7) ||  
	rcap schwaz_ub schwaz_lb tte, lw(0.2) lc(red*1.4) msiz(0.7)
	yline(0, lw(0.3) lc(gs8))
	xline(0, lp(dash) lw(0.3))
	xline(4, lp(dash) lw(0.3))
	ylabel(,labs(2) angle(0) grid glc(gs13%40) glw(0.05))
	xlabel(`r(min)'(1)`r(max)' 0 "{bf:d1}" 4 "{bf:d2}", labs(2) angle(0) grid glc(gs14%15) glw(0.3))
	title("{bf:b}", just(left) bexpand si(4) margin(b=4) span)
	ytitle("Difference in 7-day moving average per 100,000", place(12) orient(vertical) si(3) m(r=1))
	xtitle("Weeks relative to vaccination campaign (1st dose: d1)", place(12) si(3) m(t=4))
	legend(order(1 "Point estimate" 2 "95% -- CI") ring(0) pos(1) rows(1) bm("3 0 2 0") linegap(1) region(color(none)) symy(3) symx(5) si(2.5))
	note("", span si(3) linegap(1) m(t=3)) 
	plotregion(lcolor(gray*0.5) m(l=1)) graphregion(margin(2 5 2 2))
	saving(abb4b, replace);
#delimit cr
*graph export "output\graphs\schwaz\07_inf_weekly_ages.png", replace
restore


*****************************************************************************
**** Table 1, columns 4-5: 2x2 DD-estimates
**** Change in line 138 for (1): norm_av, (2) nc_icu
*****************************************************************************
g ints=(time>`event' & treat==1)
*egen id=group(gkz), label

drop if y==.

*** Absolute effect
g post=(time>(`event'))
reg y i.treat##i.post if sample, vce(cl id)

*** Semi-elasticity
replace y=ln(y+(y^2+1)^0.5)		// IHS-transf. to account for zeros
reg y i.treat##i.post if sample, vce(cl id)
di as red (exp(_coef[1.treat#1.post])-1)*100

*** Event window after March 25
g post1=(time>(`event'))
reg y i.treat##i.post1 if sample, vce(cl id)
di as red (exp(_coef[1.treat#1.post1])-1)*100

*****************************************************************************
**** Figure 4: Combined graph 
**** First, let code run with nc_goeg in line 114, then change to nc_alpha+nc_alpha1+nc_beta
*****************************************************************************
#delimit
graph combine abb4a.gph abb4b.gph, 
	graphregion(color(white)) rows(1) xsize(4) ysize(2) iscale(0.9);
#delimit cr

*** Save
graph export Fig4.png, as(png) replace

exit
