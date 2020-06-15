capture program drop balance_plot
program define balance_plot
version 13.0
syntax anything(name=treatment) [if], COVARiates(string asis) [* YLAbel(string asis) XLAbel(string asis) title(string asis)]
qui{	
	**Install cleanplots scheme
	capture which scheme-cleanplots.scheme
	if _rc!=0{
		net install cleanplots, from("https://tdmize.github.io/data/cleanplots")
	}
	
	**Install mylabels
	capture which mylabels
	if _rc!=0{
		ssc install mylabels
	}
	
	**Mark for -if- qualifier
	preserve 
	mark touse `if'
    quietly keep if touse == 1

	**Confirm covariates are passed through to program
	capture confirm existence `covariates'
	if _rc!=0 {
		di in red "Must include at least one covariate"
		exit
	}
	
	
	**Check for non-binary varibales and standardize
	foreach var in `covariates'{
		qui distinct `var'
		if r(ndistinct)>2{
			su `var', meanonly
			replace `var' = (`var' - r(min))/(r(max) - r(min))
			di "`: variable label `var''"
			lab var `var' "`: variable label `var'' {sub:standardized}"
		}
	}
	
	**Store the number of trial arms as a local
	qui levelsof `treatment', local(fill)
	local max = r(r)

	**Store the number of covariates as a local
	local num : list sizeof covariates
	
	local leglabels
	local legorder
	forval k = 1/`max'{
		local leglabels `leglabels' label(`=`k'+`max'' `: label treatment `=`k'-1'')
		local legorder `legorder' `=`k'+`max''
	}
	
	**Extract mean + SEs for each covariate for each trial arm
	foreach var in `covariates'{
		local `var'_lab: variable label `var'
		qui: mean `var', over(treatment)
		matrix `var' = r(table)
		local tag = `max'
		forval i = 1/`max'{
			local `var'_t`=`max'-`tag''_mean = `var'[1,`i']
			local `var'_t`=`max'-`tag''_se   = `var'[2,`i']
			local --tag
		}
	}

	**Set up pattern for dataset
	local fill `fill' `fill'
	
	**Make empty dataset
	clear
	set obs `=`num'*`max''
	egen treat = fill(`fill') //make treatment indicator
	gen mean = .
	gen label = ""
	gen se = .

	**Fill dataset with means + SEs
	local i = `max'
	local n = 1
	foreach var in `covariates'{
		forval t = 1/`max'{
			replace mean = ``var'_t`=`t'-1'_mean' in `n'
			replace se = ``var'_t`=`t'-1'_se' in `n'
			replace label = "``var'_lab'" if _n >=`n' & _n<=`i'
			local i = `i' + `max'
			local ++n
		}
	}
	
	**Calculate CIs
	gen ci_upper = mean+1.96*se
	gen ci_lower = mean-1.96*se

	**Multiply all vars by 100
	foreach var of varlist mean se ci_lower ci_upper{
		replace `var' = `var'*100
	}

	**Set up skip sequence for even spacing on y-axis
	/*gen seq = 1 in 1
	forval i = 2/`=_N'{
		replace seq = seq[_n-1]+`=`max'*0.5' in `i'
	}

	local i = `max'
	local m = `max'
	forval n = 1/`=_N'{
		replace seq = seq+`m' if _n>`i'
		local i = `i'+`max'
	}*/
	
	
	gen seq = 0.5 in 1
	forval i = 2/`=_N'{
		replace seq = seq[_n-1]+0.5 in `i'
	}
	
	local m = `max'
	*gen seq = _n
	forval i = 1/`num'{
		replace seq = seq+`=`max'/4' if _n>`m'
		local m `m' + `max'
		*di `m'
	}
	
	**Build xlabels
	if "`xlabel'"==""{
		qui: mylabels 0(10)100, suff(%) local(xlabs)
	}
	else{
		qui: mylabels `xlabel', suff(%) local(xlabs)
	}
	
	**Build ylabels 
	bysort label (seq): gen ylabvar = string(seq[1] + ((seq[_N]-(seq[1]))/2)) + " " + `"""' + label + `"""' + " "
	sort seq
	local ylabs
	local skip = `max'
	forval i = 1/`num'{
		local ylabs `ylabs' `=ylabvar[`skip']' 
		local skip = `skip' + `max'
	}

	**Build graph components
	local rcap
	local scatter
	forval i = 0/`=`max'-1'{
		local rcap `rcap' (rcap ci_lower ci_upper seq if treat==`i', hor msize(*0.5) lwi(thin))
		local scatter `scatter' (scatter seq mean if treat==`i', msize(medsmall))
	}
	
	twoway `rcap' ///
		   `scatter', ///
		   xlab(`xlabs', labsize(vsmall)) xti("Percentage of group in trial arm, or standardized value", size(vsmall)) ///
		   ylab(`ylabs', labsize(vsmall)) ysc(extend) ///
		   legend(`leglabels' order(`legorder') ring(1) pos(12) size(vsmall)) yti("") ///
		   scheme(cleanplots) name(balance_plot, replace) 
	list, sep(`max')
	restore
}
end
