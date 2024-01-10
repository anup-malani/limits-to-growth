* Use Penn World Tables 8 to calculate TFP (A(t))

	global rootlib "/Users/amalani/Dropbox (UChicago Law)/Fertility/Data"
	global overleafdir "/Users/amalani/Dropbox (UChicago Law)/Apps/Overleaf/Revisiting Limits to Growth - PNAS"	
	global pwtlib "$rootlib/PennWorldTables"
	global resourcelib "$rootlib/Resources"
	global powerlib "$rootlib/Power"
	global figslib "$overleafdir/figs" // <-- replace with your preferred directory
	global tabslib "$overleafdir/tabs" // <-- replace with your preferred directory

************************************
* Load PWT data
************************************

	cap frame change default
	use "$pwtlib/pwt1001.dta", clear
		
************************************
* Merge power data
************************************

	merge 1:1 year countrycode using "$powerlib/power.dta", keepusing(power countrypower)
	tab _merge
	
	drop if year > 2019 // not in PWT data
	drop if year < 1965 // not in power data
	replace country=countrypower if country==""
	
	drop if country=="World"
	drop countrypower

	// Yields power and PWT data for 1965-2019

	tabstat power emp rgdpo rnna, by(year) s(count)
		
************************************************************************
************************************************************************
* Work at country x year level
************************************************************************
************************************************************************

************************************
* Clean data
************************************

* Xtset data

	encode country, g(id)
	xtset id year
	
	xtdescribe
	
* Mark the countries in the data through 1965-2019 (power startes in 1965); before it was 1952-2019 when we ignored power

	local year_cutoff 1965
	sort id year
	keep if year >= `year_cutoff' // start after China enters PWT sample and power begins

	gen power_1965 = .
	replace power_1965 = power if year==`year_cutoff'
	by id: egen original = min(power_1965)
	drop power_1965
	replace original = original / original
	replace original = 0 if original==.
	la var original "Original 62 countries with power data in 1965" 
	
	* Address collapse of USSR.  Happens in 1991 but the data overlap starting in 1985. 
	* Replace USSR with Russian Federation, Ukraine, Azebaijan, Belarus Kazakhstan, Turkmenistan, and other CIS starting in 1985
	
	gen USSR_former = inlist(country,"Russian Federation","Ukraine","Azerbaijan","Belarus","Kazakhstan","Turkmenistan")
	replace USSR_former = 1 if inlist(country,"Estonia","Latvia","Lithuania","Uzbekistan","Tajikistan","Kyrgyzstan","Armenia","Moldova","Georgia")
		
	* Data are not smooth: 3000 TwH gap; issue with OWID, but not with Energy Inst data.  But Energy Institute data not available for small countries. https://www.energyinst.org/statistical-review.
	* All 15 countries that replace USSR have starting at least in 1992
	
	replace original = 0 if year >= 1992 & country=="USSR"
	replace original = 1 if year == 1992 & USSR_former==1 
	replace original = 1 if year > 1992 & USSR_former==1 
	drop USSR_former
	
	tab year original
	
* What percent of total power & gdp are the 92?

	* Totals are 95% for GDP, 80% for pop, 96% for power

	preserve
		gen rgdpo_orig = rgdpo*original
		gen pop_orig = pop*original
		gen power_orig = power*original
		collapse (sum) original rgdpo rgdpo_orig pop pop_orig power power_orig, by(year)
		gen rgdpo_share = rgdpo_orig/rgdpo
		gen pop_share = pop_orig/pop
		gen power_share = power_orig/power
		list year original *_share if year > 1999
	restore

* Change units

	replace rgdpo = rgdpo/1000 // from millions to billions
	replace rnna = rnna/1000
	replace emp = emp/1000 // from millions to billions
	replace pop = pop/1000	
	
* Calculate logs

	foreach x in rgdpo rnna emp pop labsh power {
		gen `x'_log = log(`x')
	}
	
* Generate growth rates

	gen g_Ne = (F.emp - emp)/emp // emp growth
	la var g_Ne "Employed pop growth rate"

	gen g_N = (F.pop - pop)/pop // emp growth
	la var g_N "Pop growth rate"

	gen y = rgdpo/pop
	gen g_y = (F.y - y)/y // pc output growth
	la var g_y "Income per capita growth rate"
	drop y
	
	gen ye = rgdpo/emp
	gen g_ye = (F.ye - ye)/ye // per emp output growth
	la var g_ye "Income per employee growth rate"
	drop ye
	
	gen g_Y = (F.rgdpo - rgdpo)/rgdpo // output growth
	la var g_Y "Output growth rate"

	gen g_X = (F.rnna - rnna)/rnna // cap stock growth
	la var g_X "Capital stock growth rate"
	
	gen xe = rnna/emp
	gen g_xe = (F.xe - xe)/xe // per emp capital growth
	la var g_xe "Capital/employee growth rate"
	
	gen g_P = (F.power - power)/power
	la var g_P "Power growth rate"
	
	gen pe = power/emp
	gen g_pe = (F.pe - pe)/pe
	la var g_pe "Power/employee growth rate"

	gen rgdpo_emp_log = rgdpo_log - emp_log // per employee income
	gen rnna_emp_log = rnna_log - emp_log // per employee capital
	gen power_emp_log = power_log - emp_log // per employee power
	
	la var rgdpo_emp_log "Log income/employee"
	la var rnna_emp_log "Log capital/employee"
	la var power_emp_log "Log power/employee"

	gen rgdpo_pop_log = rgdpo_log - pop_log // per capita income
	gen rnna_pop_log = rnna_log - pop_log // per capita capital
	gen power_pop_log = power_log - pop_log // per capita power
	
	la var rgdpo_pop_log "Log income/capita"
	la var rnna_pop_log "Log capital/capita"
	la var power_pop_log "Log power/capita"

* Constant

	gen cons = 1
	la var cons "Constant"
	
************************************
* Estimate theta from regression 
************************************

* Estimate thetaX and thetaP with growth rates.  We do this because it ensures theta estimates make power growth projections smooth relative to historical power growth.
	
	estimates clear
	
	eststo est1: reg g_ye cons g_xe g_pe if original==1, noconstant // constant is gA	

	gen thetaX = _b[g_xe]
	gen thetaP = _b[g_pe]

	la var thetaX "Capital share from country-year CD growth regs"
	la var thetaP "Power share from country-year CD growth regs"
	
************************************
* Table S1 
************************************	
	
	esttab est1, b(4) ci(4) label nonotes nomtitle
	
	esttab est1 using "$tabslib/tabS1_input.tex", ///
		replace booktab nostar nomtitle ///
		b(4) se(4) collabels("\begin{tabular}{@{}c@{}}Growth rate \\income/employee\end{tabular}") ///
		label nonotes nonum width(0.8\hsize) 
	
	* Add wrapper with a note
	
		texdoc init "$tabslib/tabS1.tex", force replace
		
		tex %-------------TABLE----------------%
		tex \begin{table}[h!]
		tex \scriptsize
		tex \caption{Estimating factor shares from historical, country-year level data from 1965-2019.}
		tex \scriptsize
		tex \label{tab:histFactShares}
		tex \begin{tabular}{lc}
		tex \input{tabs/tabS1_input.tex}
		tex \end{tabular}
		tex % Remove "& \\" from last line of input file
		tex {\raggedright \\ \sffamily Notes.  Table presents results of a regression of the growth rate of GDP per employee on the growth rate of non-power physical capital per employee and on the growth rate of power per employee.  The former yields an estimate of \(\theta_K\) and the latter an estimate of \(\theta_P\).  The constant provides an estimate of the average growth rate of TFP (\(g_A\)).  The sample includes countries with both (a) income, employee population, and capital stock and (b) power consumption for the entire period from 1965-2019.  Data are available for 66 countries from 1965-1991; in 1992 USSR is replaced with 14 countries that replaced the USSR.  Moldova is excluded due to lack of data.}
		tex \end{table}
		tex %------------------END------------------%
		
		texdoc close
		
	unique id if original==1 // 9 countries

************************************
* Table S2 
************************************	
	
	local cond "if original==1 [aw=pop]"
	
	ameans g_Y `cond' 
	scalar gY = r(mean_g)
	ameans g_P `cond' 
	scalar gP = r(mean_g)
	ameans g_X `cond' 
	scalar gX = r(mean_g)
	ameans g_Ne `cond' 
	scalar gNe = r(mean_g)

	gen gA = (gY-gNe) - (thetaX*(gX-gNe)) - (thetaP*(gP-gNe))
	
	local n 7
	matrix A = J(`n',3,.)
	matrix rownames A = "Per capita output" "Output" "Population" "Employed pop." "Capital stock" "Power" "TFP" 
	matrix colnames A = "Geometric mean" "[95\% conf." "interval]"
	local i=1
	foreach x in g_y g_Y g_N g_Ne g_X g_P {
		ameans `x' if original == 1 [aw=pop]
		matrix A[`i',1] = r(mean_g) 
		matrix A[`i',2] = r(lb_g) 
		matrix A[`i',3] = r(ub_g) 
		local i = `i'+1
	}
	
	su gA
	matrix A[`i',1] = r(mean)
	
	esttab matrix(A, fmt(4 4 4)) using "$tabslib/tabS2_input.tex", ///
		replace ///
		nonumber nomtitle booktabs 
		
		texdoc init "$tabslib/tabS2.tex", force replace
		
		tex %-------------TABLE----------------%
		tex \begin{table}[h!]
		tex \scriptsize
		tex \caption{Average country-level growth rates of key parameters from 1965-2018.}
		tex \scriptsize
		tex \label{tab:growthRates}
		tex \begin{tabular}{lccc}
		tex \input{tabs/tabS2_input.tex}
		tex \end{tabular}
		tex % Remove "& \\" from last line of input file
		tex {\raggedright \\ \sffamily Notes.  Table presents geometric means of growth rates of parameters indicated in each row (except TFP).  These means are calculated at the country x year level, where countries are weighted by their population.  Data are from 79 countries for which we have power data from 1965-2019.  2019 growth rates are omitted because we do not have data for 2020 and thus growth rates for 2019.  TFP growth is obtained by solving \eqref{eq:g_CD} \(g_A\) at the geometric means for (\(g_Y,g_L,g_K,g_P\)). Units are \%/100.}
		tex \end{table}
		tex %------------------END------------------%
		
		texdoc close
				
************************************
* Implied TFP - country year level
************************************	
		
	gen TFP_log_reg = rgdpo_emp_log - (thetaX*rnna_emp_log) - (thetaP*power_emp_log) // from growth reg generates TFP close to 48 on ave from 1965-2020, but 61.8 in 2019 
	gen TFP_reg = exp(TFP_log_reg)
	la var TFP_reg "Implied country-year TFP from country-year CD reg"
	la var TFP_log_reg "Implied log country-year TFP from country-year CD reg"
	
************************************
* Collapse to year level
************************************	
	
* Calculate total, ave, gmean of working population, income, capital, labor share by year
* Keep only countries consistently in sample, with power data
	
	gen countries=1
	
	collapse ///
		(sum) ///
		countries ///
		rgdpo_sum=rgdpo rnna_sum=rnna emp_sum=emp pop_sum=pop power_sum=power ///
		(mean) ///
		rgdpo_mean=rgdpo rnna_mean=rnna power_mean=power ///
		emp_mean=emp  pop_mean=pop  labsh_mean=labsh ///
		TFP_mean=TFP_reg ///
		rgdpo_gmean=rgdpo_log rnna_gmean=rnna_log power_gmean=power_log ///
		emp_gmean=emp_log pop_gmean=pop_log ///
		TFP_gmean=TFP_log_reg ///
		///
		, by(year)
		
		la var countries "Number of countries"
		
		la var rgdpo_sum "GDP, total 57 contries, real (billion 2017 USD, PWT10)"
		la var rnna_sum "Capital stock, total 57 countries, real (billion 2017 USD, PWT10)"
		la var power_sum "Power consumption, total 57 countries, real (billion 2017 USD, PWT10)"
		la var emp_sum "Population (employed), total57 countries, (billions, PWT10)"
		la var pop_sum  "Population , total 57 countries, (billions, PWT10)"
		
		la var rgdpo_mean "GDP, ave. country, real (billion 2017 USD, PWT10)"
		la var rnna_mean "Capital stock, ave. country, real (billion 2017 USD, PWT10)"
		la var power_mean "Power consumption, ave. country, real (billion 2017 USD, PWT10)"
		
		la var emp_mean "Population (employed), ave. country, (billions, PWT10)"
		la var pop_mean  "Population , ave. country, (billions, PWT10)"

		la var rgdpo_gmean "GDP, geometric mean/country, real (billion 2017 USD, PWT10)"
		la var rnna_gmean "Capital stock, geometric mean/country, real (billion 2017 USD, PWT10)"
		la var power_gmean "Power consumption, geometric mean/country, real (billion 2017 USD, PWT10)"
		
		la var emp_gmean "Population (employed), geometric mean/country, (billions, PWT10)"
		la var pop_gmean  "Population , geometric mean/country, (billions, PWT10)"
		
	* Take exp of mean log value to get gmean
	
	foreach x in rgdpo rnna power emp pop TFP {
		gen `x'_mlog = `x'_gmean
		replace `x'_gmean = exp(`x'_gmean)
		la var `x'_mlog "Mean of log `x'"
		gen `x'_log = log(`x'_mean)
		la var `x'_log "Log of ave. `x'"
	}

* Tsset the data

	tsset year

* 2019 values

	la var countries "Countries (no.)"
	la var emp_sum "Employed workers (billions)"
	la var pop_sum "Population (billions)"
	la var power_sum "Primary energy consumption (TwH)"
	la var TFP_mean "Average TFP ( \(\text{USD/workers}^{\theta_N} \cdot \text{TwH}^{\theta_P} \cdot \text{USD}^{\theta_K} \) )"
	la var TFP_gmean "Geometric mean TFP ( \(\text{USD/workers}^{\theta_N} \cdot \text{TwH}^{\theta_P} \cdot \text{USD}^{\theta_K} \) )"

	replace countries = round(countries)
	replace power_sum = round(power_sum)
	replace TFP_mean = round(TFP_mean,0.1)
	replace emp_sum = round(emp_sum,0.001)
	replace pop_sum = round(pop_sum,0.001)
	
	format countries %9.0fc 
	format power_sum TFP_mean TFP_gmean %9.0f 
	format emp_sum pop_sum %9.3f 

	list countries emp_sum pop_sum power_sum TFP_mean if year==2019

	mkmat countries emp_sum pop_sum power_sum TFP_mean if year==2019, ///
		mat(Awide) 
		
	matrix A = Awide'
	matrix drop Awide
		
	matrix rownames A = "Countries  (no.)" ///
		"Tot. employees (billions)" ///
		"Tot. population (billions)" ///
		"Tot. power consumption (TwH)" ///
		"TFP (ave., see note)" 

	matrix colnames A = "2019 values"

	esttab matrix(A) using "$tabslib/tabS3_input.tex", ///
		replace ///
		nonumber nomtitle booktabs 
		
		texdoc init "$tabslib/tabS3.tex", force replace
		
		tex %-------------TABLE----------------%
		tex \begin{table}[h!]
		tex \scriptsize
		tex \caption{Values of key parameters in 2019.}
		tex \scriptsize
		tex \label{tab:values2019}
		tex \begin{tabular}{lccc}
		tex \input{tabs/tabS3_input.tex}
		tex \end{tabular}
		tex % Remove "& \\" from last line of input file
		tex {\raggedright \\ \sffamily Notes.  Table presents values of key parameters indicated in each row in 2019.  Data are from 222 countris in 2019.  Average TFP is calculated using regression estimates of factor shares.  That regression is estimated on a subset of countries (66 from 1965-1991, 79 from 1992-2019).  But estimated factor shares are applied to all 222 countries for which employee, capital stock and power data are available in 2019.  Units for average TFP are \(\text{USD/[workers}^{\theta_N} \cdot \text{TwH}^{\theta_P} \cdot \text{USD}^{\theta_K}] \).}
		tex \end{table}
		tex %------------------END------------------%
		
		texdoc close	
	
	est clear

	estpost tabstat countries emp_sum pop_sum power_sum TFP_mean TFP_gmean if year ==2019, c(stat) stat(mean)

	esttab using "$tabslib/tabS3.tex", replace ////
		cells("mean") nonumber ///
		nomtitle nonote noobs label booktabs ///
		collabels("2019 values")

			texdoc init "$tabslib/tabS2.tex", force replace
			
			tex %-------------TABLE----------------%
			tex \begin{table}[h!]
			tex \scriptsize
			tex \caption{Average growth rates of key parameters for 92 countries form 2000-2018.}
			tex \scriptsize
			tex \label{tab:growthRates}
			tex \begin{tabular}{lccc}
			tex \input{tabs/tabS2_input.tex}
			tex \end{tabular}
			tex % Remove "& \\" from last line of input file
			tex {\raggedright \\ \sffamily Notes.  Table presents geometric means of growth rates of parameters indicated in each row.  These means are calculated at the country x year level, where countries are weighted by their GDP.  Data are from 92 countries for which we have power data in 1965.  Data for this table, however, are only for the the period 2000-2018.  (2019 is omitted because we do not have data for 2020 and thus growth rates for 2019.)  Units are \%/100.}
			tex \end{table}
			tex %------------------END------------------%
			
			texdoc close	
  


