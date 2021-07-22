*****************************************************************************
*** Table 1, cols (4) & (5): ES Hospitalisation
*****************************************************************************
clear all
capture log close
set more off

cd "SET WORKING DIRECTORY"

*****************************************************************************
*** Load data
*****************************************************************************
use daten/tirol_GKZ_w_2021-07-12.dta, clear

*** Keep Schwaz and neighboring districts
keep if (bezirk=="Kufstein" | bezirk=="Innsbruck-Land" | bezirk=="Schwaz")

*****************************************************************************
**** Define treatment and control group
*****************************************************************************
table gemeinde if bezirk=="Schwaz", c(m gkz)
table gemeinde if bezirk=="Innsbruck-Land", c(m gkz)
table gemeinde if bezirk=="Kufstein", c(m gkz)

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
replace treat=0 if bezirk=="Innsbruck-Land" | bezirk=="Kufstein"
table treat, c(count gkz)

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
keep gkz year week time treat nc_ages nc_goeg nc_alpha nc_alpha1 nc_beta nc_gamma norm icu pop

*** Only for cases: Switch between GOEG_ and AGES-data
g nc=nc_goeg

*** 7-day MA & incidence
xtset gkz time
g nc_av=(nc)/pop*100000					// Incidence (denom. 7 due to weekly obs.)
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
g y=norm_av							

*** Pre-treatment outcome variable
preserve
collapse (mean) y norm_av icu_av icu norm, by(treat week)
drop if week>21
sum y if treat==1 & week<`event'
table week treat, c(sum norm)
table week treat, c(sum icu)
restore

*****************************************************************************
**** Table 1, columns 4-5: 2x2 DD-estimates
**** Change in line 132 for (1): norm_av, (2) nc_icu
*****************************************************************************
g ints=(time>`event' & treat==1)
egen id=group(gkz), label

drop if y==.

*** Absolute effect
g post=(time>(`event'))
reg y i.treat##i.post if sample, vce(cl id)

*** Semi-elasticity
replace y=ln(y+(y^2+1)^0.5)		// IHS-transf. to account for zeros
reg y i.treat##i.post if sample, vce(cl id)
di as red (exp(_coef[1.treat#1.post])-1)*100

*** Event window after March 30
g post1=(time>(`event'))
reg y i.treat##i.post1 if sample, vce(cl id)
di as red (exp(_coef[1.treat#1.post1])-1)*100
exit
