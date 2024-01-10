* Preliminaries

	set more 1

	global maindir "/Users/amalani/Dropbox (UChicago Law)/Fertility/Data"
	global overleafdir "/Users/amalani/Dropbox (UChicago Law)/Apps/Overleaf/Revisiting Limits to Growth - PNAS"	

	cd "$maindir"

	cap ssc install schemepack, replace
	cap net install cleanplots, from("https://tdmize.github.io/data/cleanplots")

	set scheme rainbow
	
	cap net install scatterfit, from(https://raw.githubusercontent.com/leojahrens/scatterfit/master)
	
* Toggles

	local clean_power 1
	local clean_nonpower 1
	local clean_wb 1
	local merge 1
	local estimates 0
	local table 1
	local graphs 1
	
*****************************************
*****************************************
** Power data
*****************************************
*****************************************

if `clean_power'==1 {

	* Load power data

		import delimited "$maindir/Starnes/power.csv", numericcols(1) clear

	* Clean power data

		drop entity code
		la data "OWID"

		// Rename data
		rename biofuelstwhdirectenergy		biofuels
		rename coaltwhdirectenergy		coal
		rename gastwhdirectenergy		gas
		rename hydropowertwhdirectenergy		hydropower
		rename nucleartwhdirectenergy		nuclear
		rename oiltwhdirectenergy		oil
		rename otherrenewablestwhdirectenergy		otherrenewables
		rename solartwhdirectenergy		solar
		rename traditionalbiomasstwhdirectenerg		traditionalbiomassdirectenerg
		rename windtwhdirectenergy		wind

		 // Convert TWh to TW years
		 foreach x in "biofuels" "coal" "gas" "hydropower" "nuclear" "oil" ///
			"otherrenewables" "solar" "traditionalbiomass" "wind" {
			replace `x' = `x' / 8760 
			la var `x' "`x' (TW years)"
		}
		
		// Sum power components
		egen power = rowtotal(biofuels coal gas hydropower nuclear oil otherrenewables solar traditionalbiomass wind)
		la var power "Power (TW)"

		keep if year >= 1960

	* Save power data

		save "$maindir/resources/power.dta", replace
		
	}
	
*****************************************
*****************************************
** Non-power resources data
*****************************************
*****************************************

if `clean_nonpower'==1 {
	
	* Load metals data

		import delimited "$maindir/Starnes/all_resource_consumptions.csv", numericcols(1) clear

	* Clean metals data

		rename aluminummetrictons	 	aluminum
		rename ch4emissionstonsofco2equivalent	 	ch4emissions
		rename co2emissionstons	 	co2emissions
		rename coalmillionsoftons	 	coal
		rename coppermetrictons	 	copper
		rename freshwatercubicmeters	 	waterfresh
		rename humanpopulation	 	population
		rename ironmetrictons	 	iron
		rename landhectares	 	land
		rename leadmetrictons	 	lead
		rename lithiummetrictons	 	lithium
		rename magnesiummetrictons	 	magnesium
		rename n2oemissionstonsofco2equivalent	 	n2oemissions
		rename naturalgasbillionsofcubicmeters	 	naturalgas
		rename nickelmetrictons	 	nickel
		rename nitrogenmetrictons	 	nitrogen
		rename oilbarrels	 	oilbarrels
		rename percapitaincome2015usdollarspers	 	incomepc
		rename phosphaterockmetrictons	 	phosphate
		rename potashmetrictonspotassiumoxide	 	potash
		rename roundwoodcubicmeters	 	woodround
		rename saltmetrictons	 	salt
		rename sawnwoodcubicmeters	 	woodsawn
		rename siliconmetrictons	 	silicon
		rename sulfurmetrictons	 	sulfur
		rename tinmetrictons	 	tin
		rename zincmetrictons	 	zinc

		drop v*

		// Human pop in billions
		replace population = population / (10^9)
		la var population "Population (billions)"
		
		//Iincome in thousands
		replace incomepc = incomepc / 1000
		la var incomepc "Per cap. income (2015 USD 1000)"
		
	* Save power data

		save "$maindir/resources/resources_notpower.dta", replace
			
}

*****************************************
*****************************************
** WB GDP and population data
*****************************************
*****************************************

if `clean_wb'==1 {
	
	import delimited "$maindir/WorldBank/WorldGDPPop_Data.csv", numericcols(5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67) clear 	
		
	tab seriesname	
	
	* Largest number is GDP, and employment share is largely missing.  Use this fact to guide variable names.
	
	drop countrycode countryname seriescode seriesname
	
	xpose, clear varname
	
	* Use _varname to get year variables
	gen year = substr(_varname,3,4)
	destring year, replace
	drop _varname
	la var year "Year"
	
	* Rename variables
	su // to identify GDP and employment rate

	rename v1 Y
	replace Y = Y/1000000000000
	la var Y "GDP (trillions 2015 US$, WB)"
	
	rename v2 y
	la var y "GDP per capita (2015 US$, WB)"
	
	rename v3 N
	replace N = N/1000000000
	la var N "Population (billions, WB)"
	
	drop v4 // employment as share of pop
	
	save "$maindir/WorldBank/WorldGDPPop_Data.dta", replace
	
}

*****************************************
*****************************************
** Merged resources data
*****************************************
*****************************************

if `merge'==1 {

	* Load data
	
		use "$maindir/resources/resources_notpower.dta", clear
		
	* Merge power data

		sort year

		merge 1:1 year using "$maindir/resources/power.dta"

		tab _merge
		bysort _merge: su year
		drop _merge
		
		drop population incomepc // use WB data for this 
		
	* Merge PWT data/cleanplots
	
		sort year
		
		* merge 1:1 year using "$maindir/PennWorldTables/pwt1001collapsed.dta"
		merge 1:1 year using "$maindir/WorldBank/WorldGDPPop_Data.dta"
		
		tab _merge
		bysort _merge: su year
		drop _merge
		
	* Format years
		
		format year %ty
		
	* Tsset the data

		tsset year

		sort year

	* Clean economic variables
		
		foreach x in N y Y {
			
			gen `x'_log = log(`x')
			la var `x'_log "Log `x''"

			gen g_`x' = (F.`x' - `x') / `x'
			la var g_`x' "Growth rate of `x' (%/100, WB)"
		
		}

	* Create index, average product, logs, power ratio, time for resources, time range
	
		foreach x in land woodsawn woodround waterfresh copper aluminum iron nickel zinc tin magnesium lithium lead nitrogen phosphate potash salt silicon sulfur power {

			gen `x'_ind	 = 	`x'[_n]	 / 	`x'[1]
			la var `x'_ind "Index, `x' (1st year normalized to 1)"
			
			gen `x'_AP = Y/`x'
			la var `x'_AP "Average product of `x'"
			
			gen `x'_log = log(`x')
			la var `x'_log "Log `x''"
			
			gen `x'_AP_log = log(`x'_AP)
			la var `x'_AP_log "Log ave. prod. of `x'"
			
			gen `x'_power = `x'/power
			la var `x'_power "Ratio of `x' to power"

			gen `x'_power_1965 = `x'_power if year==1965
			replace `x'_power_1965 = `x'_power if year==1960 & `x'==land
			egen `x'_power_baseline = max(`x'_power_1965)
			replace `x'_power = `x'_power/`x'_power_baseline 
				// normalize by 1965 (1960 if land)
			
			gen g_`x' = (F.`x' - `x') / `x'
			la var g_`x' "Growth rate of `x' (%/100)"
			
			clonevar `x'_g = g_`x' 
		
			g `x'_year_min = (`x'[_n] != . & (`x'[_n-1] == . | year==1950))
			g `x'_year_max = (`x'[_n] != . & (`x'[_n+1] == . | year==2021))
			replace `x'_year_min = `x'_year_min*year
			replace `x'_year_max = `x'_year_max*year
			di "`x'_year_min"
			list `x'_year_min if `x'_year_min > 1 & `x'_year_min != .
			di "`x'_year_max"
			list `x'_year_max if `x'_year_max > 1 & `x'_year_max != .
			
		} 

		replace land_year_min = 1960 // fix 2 errors in my year_min formula
			// Errors casues by non-continuous data, i.e., . then data then .
		replace waterfresh_year_min = 1960
		
	* Gen pop and TFP growth and acceleration

		la var g_Y "Growth rate of GDP (%/100, WB)"
		
		la var g_N "Growth rate of population (%/100, WB)"

		la var g_y "Growth rate of per capita GDP (%/100, WB)"
		
		gen g_P = g_power
		la var g_P "Growth rate of power (%/100, OWID)"
		
		gen g_AP = g_Y - g_power
		la var g_P "Growth rate of average product of power (%/100, OWID)"
		
	* Calculate 1+growth rates (useful for taking geometric means)
	
		foreach x in "P" "N" "y" "Y" "AP" {
			
			gen G_`x' = 1 + g_`x'
			la var G_`x' "1 + g_`x'"
			
		} 
		
	* Save result

		save "$maindir/resources.dta", replace
		
}
	
*****************************************
*****************************************
** Table
*****************************************
*****************************************

if `table'==1 {
	
	* Load data/cleanplots

		use "$maindir/resources.dta", clear
		
	* tsset data/cleanplots
	
		tsset year
		
		foreach x in land woodsawn woodround  waterfresh copper aluminum ///
			iron nickel zinc tin magnesium lithium lead nitrogen phosphate ///
			potash sulfur power {
			
			g `x'_G_log = log(1 + `x'_g)
			g `x'_AP_g = (F.`x'_AP - `x'_AP)/`x'_AP
			g `x'_AP_G_log = log(1+ `x'_AP_g) 
			g `x'_power_G = 1 + `x'_g - power_g
			g `x'_power_G_log = log(`x'_power_G)

		}
		
		collapse ///
			(mean) ///
				land_G_log ///
				woodsawn_G_log ///
				woodround_G_log ///
				waterfresh_G_log ///
				copper_G_log ///
				aluminum_G_log ///
				iron_G_log ///
				nickel_G_log ///
				zinc_G_log ///
				tin_G_log ///
				magnesium_G_log ///
				lithium_G_log ///
				lead_G_log ///
				nitrogen_G_log ///
				phosphate_G_log ///
				potash_G_log ///
				sulfur_G_log ///
				power_G_log ///
				land_AP_G_log ///
				woodsawn_AP_G_log ///
				woodround_AP_G_log ///
				waterfresh_AP_G_log ///
				copper_AP_G_log ///
				aluminum_AP_G_log ///
				iron_AP_G_log ///
				nickel_AP_G_log ///
				zinc_AP_G_log ///
				tin_AP_G_log ///
				magnesium_AP_G_log ///
				lithium_AP_G_log ///
				lead_AP_G_log ///
				nitrogen_AP_G_log ///
				phosphate_AP_G_log ///
				potash_AP_G_log ///
				sulfur_AP_G_log ///
				power_AP_G_log ///
				land_power_G_log ///
				woodsawn_power_G_log ///
				woodround_power_G_log ///
				waterfresh_power_G_log ///
				copper_power_G_log ///
				aluminum_power_G_log ///
				iron_power_G_log ///
				nickel_power_G_log ///
				zinc_power_G_log ///
				tin_power_G_log ///
				magnesium_power_G_log ///
				lithium_power_G_log ///
				lead_power_G_log ///
				nitrogen_power_G_log ///
				phosphate_power_G_log ///
				potash_power_G_log ///
				sulfur_power_G_log ///
				power_power_G_log ///
			(max) ///
				land_year_min ///
				woodsawn_year_min ///
				woodround_year_min ///
				waterfresh_year_min ///
				copper_year_min ///
				aluminum_year_min ///
				iron_year_min ///
				nickel_year_min ///
				zinc_year_min ///
				tin_year_min ///
				magnesium_year_min ///
				lithium_year_min ///
				lead_year_min ///
				nitrogen_year_min ///
				phosphate_year_min ///
				potash_year_min ///
				sulfur_year_min ///
				power_year_min ///
				land_year_max ///
				woodsawn_year_max ///
				woodround_year_max ///
				waterfresh_year_max ///
				copper_year_max ///
				aluminum_year_max ///
				iron_year_max ///
				nickel_year_max ///
				zinc_year_max ///
				tin_year_max ///
				magnesium_year_max ///
				lithium_year_max ///
				lead_year_max ///
				nitrogen_year_max ///
				phosphate_year_max ///
				potash_year_max ///
				sulfur_year_max ///
				power_year_max ///

		gen power_g = exp(power_G_log)-1
				
		foreach x in land woodsawn woodround  waterfresh copper aluminum iron nickel zinc tin magnesium lithium lead nitrogen phosphate potash sulfur power {
			
			cap gen C_`x'_g = (exp(`x'_G_log)-1)*100 // calculate gmean
			drop `x'_G_log
			
			gen D_`x'_AP_g = (exp(`x'_AP_G_log) - 1)*100
			drop `x'_AP_G_log
			
			gen E_`x'_power_g = (exp(`x'_power_G_log) - 1)*100
			drop `x'_power_G_log
			
			rename `x'_year_min A_year_min_`x'
			rename `x'_year_max B_year_max_`x'

		}
		
		drop power_g
		aorder
		
		export excel "$maindir/Results/Tab1_raw.xlsx", replace firstrow(var)

}
	
	
*****************************************
*****************************************
** Graphs
*****************************************
*****************************************

if `graphs'==1 {
		
	* Load data/cleanplots

		use "$maindir/resources.dta", clear

	* Calculate geometric means of growth factors, implied rates
		
		keep if year >=1965
		su year
			
		foreach x in "P" "N" "y" {
			
			ameans G_`x'
			local gmean_g_`x' = round((r(mean_g)-1)*100,0.01)
			local amean_g_`x' = round((r(mean)-1)*100,0.01)
			
		}
			
	* Calculate growth of ave prod as sum of growths: g_y + g_N - g_P 
	
		local gmean_g_AP = round((`gmean_g_N'+`gmean_g_y') - `gmean_g_P',0.01)  
	
	* Graph components of power

		local opts "msize(small) mc(green) yscale(log) nodraw xlabel(, labsize(medium)) ylabel(#5, labsize(medium)) " // common options
		
		gr twoway scatter power year, ///
			title("g{sub:P} = `gmean_g_P'%/yr", size(medium)) ///
			ytitle("Power (TW)", size(medium)) ///
			xtitle("", size(medium)) ///
			`opts' saving(1A, replace)	
			
		gr twoway scatter N year, ///
			title("g{sub:N} = `gmean_g_N'%/yr", size(medium))  ///
			ytitle("Population (billions)", size(medium)) ///
			xtitle("", size(medium)) ///
			`opts' saving(1B, replace)	
		
		replace y = y/1000 // Convert per capita GDP to $thousands
		
		gr twoway scatter y year, /// 
			title("g{sub:y} = `gmean_g_y'%/yr", size(medium)) ///
			ytitle("Income per capita" "(thousand 2015 USD)", size(medium)) ///
			xtitle("Year", size(medium)) ///
			`opts' saving(1C, replace)	
			
		gr twoway scatter power_AP year, ///
			title("g{sub:AP} = `gmean_g_AP'%/yr", size(medium)) ///
			ytitle("Average productivity" "(trillion 2015 USD/TW)", size(medium)) ///
			xtitle("Year", size(medium)) ///
			text(5.66 1984 "_") ///
			`opts' saving(1D, replace)	
			
		gr combine 1A.gph 1B.gph 1C.gph 1D.gph, r(2) c(2)
		
		* gr export "$maindir/Results/Fig1.png", replace
		gr export "$overleafdir/figs/Fig1.png", replace
		
		erase "1A.gph" 
		erase "1B.gph" 
		erase "1C.gph" 
		erase "1D.gph"
		
	* Graph power ratios

		*replace prat_lithium = . if prat_lithium>3
		
		local opts1 "yline(1, lp(--) lc(black)) yscale(log) "
		local opts2 "xlabel(#10, labsize(small)) nodraw"
		local lopts "r(2) pos(10) ring(0) size(small)"

		gr twoway ///
			(line land_power year if year >= 2000 & year <= 2020, lw(medthick)) ///
			|| ///
			(line woodsawn_power woodround_power waterfresh_power year ///
			if year >= 1965 & year <= 2020, lw(medthick medthick medthick)), ///
			`opts1' `opts2' ///
			ylabel(.25 .5 .75 1 2, labsize(small)) ///
			ytitle("Ratio (index: 1965 = 1)") ///
			xtitle("") ///
			legend(order(1 "Land" 2 "Wood, sawn" 3 "Wood, round" ///
				4 "Water, fresh") `lopts') ///
			saving(3a, replace) 
		
		gr twoway line nitrogen_power phosphate_power potash_power ///
			sulfur_power year ///
			if year >= 1965 & year <= 2020, ///
			lw(medthick medthick medthick medthick) ///
			`opts1' `opts2' ///
			ylabel(.5 .75 1 1.5 2 4, labsize(small)) ///
			xtitle("") ///
			legend(order(1 "Nitrogen" 2 "Phosphate" 3 "Potash" 4 "Sulphur") ///
				`lopts')  ///
			saving(3b, replace)

		gr twoway line aluminum_power copper_power iron_power nickel_power year ///
			if year >= 1965 & year <= 2020, ///
			lw(medthick medthick medthick medthick) ///
			`opts1' `opts2' ///
			ylabel(.75 1 1.5 2 2.5 3, labsize(small)) ///
			ytitle("Ratio (index: 1965 = 1)") ///
			xtitle("Year", size(medium)) ///
			legend(order(1 "Aluminum" 2 "Copper" 3 "Iron" 4 "Nickel") `lopts') ///
			saving(3c, replace)
		
		gr twoway line zinc_power tin_power magnesium_power lithium_power ///
			lead_power year ///
			if year >= 1965 & year <= 2020, ///
			lw(medthick medthick medthick medthick) ///
			`opts1' `opts2' ///
			ylabel(.125 .25 .5 1 2 4 8, labsize(small)) ///
			xtitle("Year", size(medium)) ///
			legend(order(1 "Zinc" 2 "Tin" 3 "Magnesium" 4 "Lithium" 5 "Lead") ///
				`lopts') ///
			saving(3d, replace) 

		gr combine 3a.gph 3b.gph 3c.gph 3d.gph, r(2) c(2) // ycommon
		
// 		gr export "$maindir/Results/Fig5.png", replace
		gr export "$overleafdir/figs/Fig5.png", replace
		
		erase "3a.gph" 
		erase "3b.gph" 
		erase "3c.gph" 
		erase "3d.gph" 
	
}









/*

CHAFF

*****************************************
*****************************************
** PWT data --> DROP
*****************************************
*****************************************

// if `clean_pwt'==1 {
//	
// 	global rootlib "/Users/amalani/Dropbox (UChicago Law)/Fertility/Data/"
//
// 	use "$maindir/PennWorldTables/pwt1001.dta", clear
//
// 	collapse (sum) gdp_real_pwt=rgdpo capstock_real_pwt=rnna pop_emp_pwt=emp pop_pwt=pop ///
// 		, by(year)
//		
// 	replace gdp_real_pwt = gdp_real_pwt/1000000
// 	la var gdp_real_pwt "real global GDP (trillions USD)"
//	
// 	replace capstock_real_pwt = capstock_real_pwt/1000000
// 	la var capstock_real_pwt "real global GDP (trillions USD)"
//	
// 	replace pop_emp_pwt = pop_emp_pwt/1000
// 	la var pop_emp_pwt "Employed population (billions)"
//
// 	replace pop_pwt = pop_pwt/1000
// 	la var pop_pwt "Population (billions)"
//
// 	save "$maindir/resources/pwt1001.dta", clear
//		
// }
//

*****************************************
*****************************************
** Estimates
*****************************************
*****************************************

// if `estimates'==1 {
//		
// 	* Load data/cleanplots
//
// 		use "$maindir/resources.dta", clear
//
// 	// * Calculate growth rates w/ regs
// 	//
// 	// 	foreach x in "power" "pop" "incomepc" "AP" {
// 	//		
// 	// 		regress `x'_log year
// 	// 		local g_`x' = round(_b[year]*100,0.01)
// 	//		
// 	// 	}
//
//				
// 	* Generate log of g_A
//	
// 		foreach x in pwt CD {
//			
// 			g g_A_`x'_log = log(g_A_`x')
//
// 		}
//	
// 	* Plot the relevant items
//	
// // 		twoway (scatter g_A_pwt_log year, yaxis(1)) || ///
// // 			(scatter pop_pwt_log TFP_log year, yaxis(2))
//			
// 		reg rgdpo_log rnna_log pop_pwt_log
//		
// 		twoway scatter rgdpo_log rnna_log pop_pwt_log year
//		
// 		stop
//	
// 	* Calculate growth and acceleration
//
// 		ameans g_P g_N g_Ne g_Y g_y g_A_pwt g_A_CD a_A_pwt a_A_CD
//		
// 	* Estimates of lambda and beta
//		
// 		foreach x in pwt CD {
//			
// 			reg g_A_`x'_log pop_pwt_log TFP_log // use log g_A and N
// 			reg g_A_`x'_log pop_emp_pwt_log TFP_log // use log g_A and Ne 
//			
// 			reg a_A_`x' g_N g_A_`x', noconstant  // use a_A and g_N
// 			reg a_A_`x' g_Ne g_A_`x', noconstant // use a_A and g_Ne
//			
// 		}
//		
// 	* Estimates of (- beta) given lambda = 1 or 0.75
//	
// 		foreach x in 100 075 {
//			
// 			// This approach allows a constant
// 			gen f_b_`x' = ((`x'/100)*pop_pwt_log) - g_A_pwt_log
// 			reg f_b_`x' TFP_log
//			
// 			gen bxg_A`x' = (g_N * (`x'/100)) - a_A_pwt // a_A = lam g_N + beta g_A 
// 			gen bxg_A`x'e = (g_Ne * (`x'/100)) - a_A_pwt
// 			reg bxg_A`x' g_A_pwt, noconstant // beta * g_A --> coef = - beta
// 			reg bxg_A`x'e g_A_pwt, noconstant
//						
// 		}
//		
// 		reg a_A g_N g_A 
// 		reg a_A g_N g_A, noconstant 
// 		reg a_A g_A
// 		reg g_A g_N
//			
// 	* Plot acceleration
//	
// 		sort year 
// 		twoway (scatter a_A year) || (line  a_A year)
//		
// 		stop
//		
// 		scatterfit a_A g_N if inrange(a_A,-5,5), fit(lfitci) cov(g_A) coef
//		
// 		stop 
//		
// 		*twoway (scatter a_A g_N if inrange(a_A,-5,5)) || (lfit a_A g_N if inrange(a_A,-5,5)), saving(a_A1, replace) nodraw ytitle(a_A)
// 		twoway (scatter a_A g_A if inrange(a_A,-5,5)) || (lfit a_A g_A if inrange(a_A,-5,5)), saving(a_A2, replace) nodraw ytitle(a_A)
// 		gr combine a_A1.gph a_A2.gph, r(1)
//		
// 		* twoway scatter a_A year || qfit a_A year
//
// }

// 	* Graph g_p over time
//	
// 		di "y = `gmean_g_N' + 25*(`gmean_g_y' - (exp(0.0157 * (x-2020)) * `gmean_g_A') - `gmean_g_P'"
// 		di "y = `amean_g_N' + 25*(`amean_g_y' - (exp(0.0157 * (x-2020)) * `amean_g_A') - `amean_g_P'"
//	
// 		gen g_P_prederr = g_N + 25*(g_y - g_A) - g_P
// 		su g_P_prederr
// 		list year g_P_prederr if year==2020
//	
// 		sort year
// 		set obs `=_N+1'
// 		replace year[_N+1] = 2021
		
// 		twoway (function y = `amean_g_P'*(x^0),range(2020 2025)) || ///
// 			(function y = max(`amean_g_N' + 25*(`amean_g_y' - (exp(0.0157 * (x-2020)) * `amean_g_A')),0) - `amean_g_P', ///
// 			range(2020 2025) ytitle("g_P"))
					
		* twoway  (function y = max(g_N[_N] + 25*(g_y[_N] - (exp(0.0157 * (x-2020)) * g_A[_N])),0), range(2020 2500) ytitle("g_P")) 
	
// 		rename gK g_X
// 		la var g_X "Growth rate of capital stock (%/100, PWT)"
//		
// 		gen g_A_CD = g_Y - (0.04 * g_P) - (0.49 * g_Ne) - (0.47 * g_X)
// 		la var g_A_CD "Growth of TFP (g_A, derived from Cobb-Douglas production and PWT)"
//		
// 		gen a_A_CD = (F.g_A_CD - g_A_CD) / g_A_CD
// 		la var a_A_CD "Acceleration of TFP (g_A, derived from Cobb-Douglas production and PWT)"
		
// 		gen g_AP_power = (F.power_AP - power_AP)/power_AP		
// 		gen g_A = g_y + (0.04*(g_N-g_P))
// 		gen g_A_ = g_AP - (0.96*(g_N-g_P))
// 		gen a_A = (g_A - L.g_A)/L.g_A
		
// 		foreach x in "P" "N" "Ne" "A_pwt" "A_CD" "y" "Y" "AP" {

// 		foreach x in A_pwt A_CD {
// 			gen A_`x' = 1+a_`x'
// 			la var A_`x' "1 + a_`x'"
// 		}
		


*/
