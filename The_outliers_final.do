* Import the dataset
import delimited "D:/STATA 13 SOFTWARE/data/econometrics_regression_data_1.csv", clear varnames(1)

* Save raw data before cleaning
save "D:/STATA 13 SOFTWARE/data/raw_data.dta", replace

* Drop unnecessary variables
drop countryname countrycode time timecode gdppercapitagrowthannualnygdppca
drop v24 v25 v26 v27

* Rename variables for clarity
rename gdppercapitaconstant2015usnygdpp gdp_pc 
rename mortalityrateinfantper1000livebi infant_mortality  
rename currenthealthexpenditureofgdpshx health_expenditure  
rename lifeexpectancyatbirthtotalyearss life_expectancy  
rename peopleusingatleastbasicdrinkingw water_access  
rename peopleusingatleastbasicsanitatio sanitation_access  
rename prevalenceofundernourishmentofpo undernourishment  
rename pm25airpollutionmeanannualexposu pm25  
rename literacyrateadulttotalofpeopleag literacy_rate  
rename physiciansper1000peopleshmedphys physicians  
rename employmenttopopulationratio15tot employment_rate  
rename urbanpopulationoftotalpopulation urban_population  
rename immunizationdptofchildrenages122 immunization  
rename prevalenceofcurrenttobaccouseofa smoking_rate  
rename mortalityrateunder5per1000livebi under5_mortality  
rename maternalmortalityrationationales maternal_mortality  
rename prevalenceofseverefoodinsecurity food_insecurity  
rename giniindexsipovgini gini_index  

* Replace ".." with missing values and convert string variables to numeric
foreach var of varlist _all {
    replace `var' = "." if `var' == ".."
    destring `var', replace force
}

* Create a new variable counting non-missing values across rows
egen nonmissing_cnt = rownonmiss(*)
* Drop rows with 6 or fewer non-missing values
drop if nonmissing_cnt <= 6
drop nonmissing_cnt

* Initialize local macros for variables to drop and normalize
local drop_vars ""
local normalize_vars ""

* Loop through variables to handle missing values
foreach var of varlist _all {
    qui count if missing(`var')
    local nmiss = r(N)
    local total = _N
    local percent_missing = (`nmiss' / `total') * 100

    * Drop variables with more than 40% missing data
    if `percent_missing' > 40 {  
        local drop_vars "`drop_vars' `var'"
    }
    else{  
        * For variables with 20-40% missing, replace missing with median, else with mean
        qui sum `var', detail
        local mean_val = r(mean)
        local median_val = r(p50)

        if `percent_missing' >= 20 {
            replace `var' = `median_val' if missing(`var')  
        }
        else if `percent_missing' > 0 {
            replace `var' = `mean_val' if missing(`var')  
        }

        * Mark variables for normalization
        if "`var'" != "life_expectancy" {
            local normalize_vars "`normalize_vars' `var'"
        }
    }
}

* Drop variables that exceed the missing data threshold
drop `drop_vars'

* Normalize selected variables (scale to 0-10)
foreach var of local normalize_vars {
    qui sum `var'
    local max_val = r(max)
    replace `var' = 10 * `var' / `max_val'
}

* Save cleaned data
save "D:/STATA 13 SOFTWARE/data/cleaned_data.dta", replace

* Run correlations among key variables
corr gdp_pc infant_mortality health_expenditure water_access sanitation_access pm25 physicians employment_rate urban_population immunization under5_mortality

* Drop irrelevant variables from the correlation analysis
drop under5_mortality urban_population sanitation_access immunization

* Run regression of life expectancy on selected variables
reg life_expectancy gdp_pc infant_mortality health_expenditure water_access pm25 physicians employment_rate

* Drop unnecessary variables for the next regression
drop employment_rate water_access physicians

* Run a second regression with fewer variables
reg life_expectancy gdp_pc infant_mortality health_expenditure pm25

* Check for multicollinearity (Variance Inflation Factor)
vif

* Perform heteroskedasticity test
estat hettest

* Predict residuals and check normality
predict resid, residuals
qnorm resid
drop resid

* Cook's distance to check for influential observations
predict cooksd, cooksd
drop if cooksd >= 0.001

* Run final regression after removing influential points
reg life_expectancy gdp_pc infant_mortality health_expenditure pm25

* Check multicollinearity again after cleaning
vif

* Perform heteroskedasticity test again
estat hettest

* Predict residuals and check normality again
predict resid, residuals
qnorm resid
