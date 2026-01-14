log using "C:\Users\Nikhil Bhandarkar\Documents\gradschool\fs_2025\data analysis\final_exercise\extension.log"
* ---------------------------------------------------------------------------
* PROJECT: Extension of Weinstein (2025) - STEM Majors & Recession
* FINAL CLEAN VERSION (Fixed Part 10 Nested Preserve)
* ---------------------------------------------------------------------------

clear all
set more off
set linesize 200

* --- INSTALL REQUIRED PACKAGES (Only if missing) ---
local packages reghdfe ftools coefplot estout
foreach pkg in `packages' {
    capture which `pkg'
    if _rc != 0 ssc install `pkg', replace
}

* ---------------------------------------------------------------------------
* PART 0: DEFINE PATHS
* ---------------------------------------------------------------------------
* UPDATED: Set your root directory here once
local user_root "C:\Users\Nikhil Bhandarkar\Documents\gradschool\fs_2025\data analysis"

global data_path   "`user_root'\final_exercise\193625-V1\ReplicationPackage_FinalAccept\ReplicationPackage"
global ipeds_path  "`user_root'\final_exercise\new_extension_data\ipeds_raw"
global output_path "`user_root'\final_exercise\output"

* Create output directory if needed
capture mkdir "$output_path"

* ---------------------------------------------------------------------------
* PART 1: PROCESS EXTERNAL STEM DATA (IPEDS LOOP)
* ---------------------------------------------------------------------------

tempfile ipeds_combined
save `ipeds_combined', emptyok
local files_processed = 0

* Loop through years corresponding to birth cohorts 1980-1991
forvalues y = 2002/2013 {
    
    display "Processing IPEDS Year: `y'..."
    local file_loaded = 0
    
    * Attempt to load file (checking priorities: .dta -> .csv -> alt .csv)
    if `file_loaded' == 0 {
        capture use "$ipeds_path\c`y'_a.dta", clear
        if _rc == 0 local file_loaded = 1
    }
    if `file_loaded' == 0 {
        capture import delimited "$ipeds_path\c`y'_a.csv", clear case(lower)
        if _rc == 0 local file_loaded = 1
    }
    if `file_loaded' == 0 {
        capture import delimited "$ipeds_path\C`y'_data.csv", clear case(lower)
        if _rc == 0 local file_loaded = 1
    }
    
    if `file_loaded' == 1 {
        capture rename *, lower
        
        * --- FILTER: Bachelor's Degrees Only ---
        capture destring awlevel, replace force
        keep if awlevel == 5
        
        * --- CIP CODE Conversion ---
        capture confirm string variable cipcode
        if _rc != 0 tostring cipcode, replace force
        gen str2 cip2 = substr(cipcode, 1, 2)
        
        * --- HANDLE TOTAL VARIABLE ---
        capture confirm variable ctotalt
        if _rc != 0 {
             capture confirm variable crace24
             if _rc == 0 gen ctotalt = crace24
             else {
                capture confirm variable crace15 crace16
                if _rc == 0 gen ctotalt = crace15 + crace16
             }
        }

        * --- DEFINE STEM (NSF Definition) ---
        gen is_stem = inlist(cip2, "11", "14", "15", "26", "27", "40")
        drop if cip2 == "99" 

        gen stem_count = ctotalt if is_stem == 1
        replace stem_count = 0 if missing(stem_count)
        
        collapse (sum) total_awards=ctotalt (sum) stem_awards=stem_count, by(unitid)
        
        gen pct_stem = stem_awards / total_awards
        replace pct_stem = 0 if missing(pct_stem)
        gen grad_year = `y'
        
        * Optimized: Append to tempfile rather than saving to disk in loop
        append using `ipeds_combined'
        save `ipeds_combined', replace
        local files_processed = `files_processed' + 1
    } 
    else {
        display as text "Warning: Could not find data for year `y'"
    }
}

if `files_processed' == 0 {
    display as error "ERROR: No IPEDS data files were successfully loaded."
    exit 198 
}

use `ipeds_combined', clear
gen birth_cohort = grad_year - 22
duplicates drop unitid birth_cohort, force
label var pct_stem "Fraction of degrees in STEM fields"

save "$output_path\ipeds_stem_clean.dta", replace
display "Part 1 Complete: IPEDS data cleaned."

* ---------------------------------------------------------------------------
* PART 2: MERGE WITH REPLICATION DATA
* ---------------------------------------------------------------------------

cd "$data_path"
display "Scanning for Crosswalk File..."

* Optimized file search
local crosswalk_file ""
local files : dir . files "*.dta"

foreach f in `files' {
    if inlist("`f'", "ipeds_stem_clean.dta", "ipeds_combined_temp.dta", "mrc_table3.dta", "crosswalk_map_temp.dta") continue
    
    quietly use "`f'", clear
    capture confirm variable unitid super_opeid
    if _rc == 0 {
        local crosswalk_file "`f'"
        display "SUCCESS: Found Crosswalk file: `f'"
        continue, break
    }
}

if "`crosswalk_file'" == "" {
    display as error "CRITICAL ERROR: No crosswalk file found."
    exit 198
}

use "`crosswalk_file'", clear

* FIXED: Make cz optional
capture keep super_opeid unitid cz
if _rc != 0 keep super_opeid unitid

duplicates drop unitid, force
save "crosswalk_map_temp.dta", replace

use "$output_path\ipeds_stem_clean.dta", clear
merge m:1 unitid using "crosswalk_map_temp.dta", keep(3) nogenerate

collapse (sum) total_awards (sum) stem_awards, by(super_opeid birth_cohort)
gen pct_stem = stem_awards / total_awards
label var pct_stem "Fraction of degrees in STEM fields (System Level)"

save "$output_path\ipeds_stem_system_clean.dta", replace

use "mrc_table3.dta", clear
capture rename cohort birth_cohort
merge 1:1 super_opeid birth_cohort using "$output_path\ipeds_stem_system_clean.dta", keep(1 3) nogenerate

* ---------------------------------------------------------------------------
* PART 3: PREPARE VARIABLES FOR REGRESSION
* ---------------------------------------------------------------------------

gen recession_cohort = (birth_cohort >= 1987)

capture confirm variable ln_k_median
if _rc != 0 {
    gen ln_k_median = log(k_median)
    label var ln_k_median "Log Median Earnings"
}

capture confirm variable unemp_shock
if _rc != 0 {
    display as text "WARNING: 'unemp_shock' missing. Creating PLACEHOLDER."
    gen severe_recession = 0 
} 
else {
    quietly summarize unemp_shock, detail
    gen severe_recession = (unemp_shock > r(p50))
}

capture confirm variable cz
if _rc == 0 gen cz_id = cz 
else gen cz_id = 1 

* ---------------------------------------------------------------------------
* PART 4: ANALYSIS (ADAPTIVE)
* ---------------------------------------------------------------------------

eststo clear
quietly summarize severe_recession
local sd_severe = r(sd)

if `sd_severe' == 0 {
    display as text "SWITCHING TO DOUBLE-DIFFERENCE MODEL (No Shock Data)"
    local keep_vars "*.tier#1.recession_cohort"

    reghdfe pct_stem i.tier##i.birth_cohort, absorb(super_opeid cz_id#birth_cohort) cluster(super_opeid)
    coefplot, keep(*.tier#*.birth_cohort) vertical title("Change in STEM Major Share by Tier") yline(0) rename(*.tier#*.birth_cohort = "")
    eststo stem_event_study

    reghdfe ln_k_median i.tier##i.recession_cohort, absorb(super_opeid cz_id#birth_cohort) cluster(super_opeid)
    eststo baseline
    reghdfe ln_k_median i.tier##i.recession_cohort c.pct_stem##i.recession_cohort, absorb(super_opeid cz_id#birth_cohort) cluster(super_opeid)
    eststo with_mechanism
}
else {
    display as text "RUNNING TRIPLE-DIFFERENCE MODEL"
    local keep_vars "*.tier#1.recession_cohort#1.severe_recession"

    reghdfe pct_stem i.tier##i.birth_cohort##i.severe_recession, absorb(super_opeid cz_id#birth_cohort) cluster(super_opeid)
    coefplot, keep(*.tier#*.birth_cohort#1.severe_recession) vertical title("Diff-in-Diff-in-Diff: STEM Major Share") yline(0) rename(*.tier#*.birth_cohort#1.severe_recession = "") 
    eststo stem_event_study

    reghdfe ln_k_median i.tier##i.recession_cohort##i.severe_recession, absorb(super_opeid cz_id#birth_cohort) cluster(super_opeid)
    eststo baseline
    reghdfe ln_k_median i.tier##i.recession_cohort##i.severe_recession c.pct_stem##i.recession_cohort##i.severe_recession, absorb(super_opeid cz_id#birth_cohort) cluster(super_opeid)
    eststo with_mechanism
}

* ---------------------------------------------------------------------------
* PART 5: OUTPUT MAIN TABLE
* ---------------------------------------------------------------------------
esttab baseline with_mechanism using "$output_path\STEM_Extension_Results.tex", ///
    replace booktabs fragment label ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
    keep(`keep_vars') ///
    mtitles("Baseline Gap (Log)" "With STEM Control") ///
    title("Effect of STEM Major Composition on Income Gap")

* ---------------------------------------------------------------------------
* PART 6: DESCRIPTIVE TRENDS (AGGREGATE)
* ---------------------------------------------------------------------------
preserve
    gen tier_group = .
    replace tier_group = 1 if tier == 1
    replace tier_group = 2 if tier == 2
    replace tier_group = 3 if inlist(tier, 3, 4, 5)
    keep if tier_group != .
    
    label define tier_grp_lab 1 "Ivy Plus" 2 "Other Elite (Tier 2)" 3 "Selective (Tiers 3-5)"
    label values tier_group tier_grp_lab
    collapse (mean) mean_stem=pct_stem, by(birth_cohort tier_group)
    
    twoway (line mean_stem birth_cohort if tier_group==1, lwidth(thick) lcolor(navy)) ///
           (line mean_stem birth_cohort if tier_group==2, lwidth(medium) lpattern(dash) lcolor(maroon)) ///
           (line mean_stem birth_cohort if tier_group==3, lwidth(medium) lpattern(solid) lcolor(forest_green)), ///
           title("Trend in STEM Major Share by Selectivity Tier") ///
           subtitle("1980-1991 Birth Cohorts (Approx Class of 2002-2013)") ///
           xtitle("Birth Cohort") ytitle("Fraction of Degrees in STEM") ///
           legend(order(1 "Ivy Plus" 2 "Other Elite" 3 "Selective (Tiers 3-5)")) ///
           xline(1987, lpattern(dot) lcolor(black)) text(0.25 1987 "Recession Onset", place(e)) ///
           graphregion(color(white))
    graph export "$output_path\STEM_Trends_Graph.png", replace
restore

* ---------------------------------------------------------------------------
* PART 7 & 8: IVY PLUS HETEROGENEITY & SCATTER
* ---------------------------------------------------------------------------
preserve
    keep if tier == 1
    
    * FIXED: Check if 'name' exists before creating
    capture confirm variable name
    if _rc != 0 gen name = "Uni " + string(super_opeid)
    
    * Naming conventions
    replace name = "MIT" if strpos(name, "Massachusetts Institute") > 0
    replace name = "UPenn" if strpos(name, "Pennsylvania") > 0
    replace name = "Columbia" if strpos(name, "Columbia") > 0

    local school_colors "sienna ltblue red forest_green midblue maroon gray dkorange cranberry purple navy black"

    * Trend Graph
    separate pct_stem, by(name) veryshortlabel
    twoway (line pct_stem?* birth_cohort, lw(medium) color(`school_colors')), ///
        title("STEM Major Share: Individual Ivy Plus Universities") ///
        subtitle("Heterogeneity within Tier 1 (1980-1991 Cohorts)") ///
        xtitle("Birth Cohort") ytitle("Fraction of Degrees in STEM") ///
        legend(position(3) cols(1) size(vsmall) region(lcolor(none))) ///
        xline(1987, lpattern(dot) lcolor(black)) graphregion(color(white))
    graph export "$output_path\Ivy_Plus_Trends.png", replace

    * Scatter Analysis
    eststo clear
    eststo: reg ln_k_median pct_stem
    eststo: reghdfe ln_k_median pct_stem, absorb(birth_cohort)
    esttab using "$output_path\Ivy_Plus_STEM_Earnings_Table.tex", replace ///
        booktabs fragment label ///
        cells(b(star fmt(3)) se(par fmt(3))) ///
        stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
        title("Relationship between Earnings and STEM (Ivy Plus Only)") ///
        mtitles("Simple" "Cohort FE")

    * Scatter Plot with Cohort Slopes
    gen cohort_label = ""
    levelsof birth_cohort, local(cohorts)
    foreach c of local cohorts {
        quietly reg ln_k_median pct_stem if birth_cohort == `c'
        local b : display %4.3f _b[pct_stem]
        replace cohort_label = "`c' (b=`b')" if birth_cohort == `c'
    }

    separate ln_k_median, by(name) veryshortlabel
    twoway (scatter ln_k_median?* pct_stem, ///
                mcolor(`school_colors') msize(small) msymbol(circle)) ///
           (lfit ln_k_median pct_stem, lcolor(black) lwidth(medium)), ///
           by(cohort_label, title("Earnings vs STEM Share by Cohort") ///
              legend(position(3) size(tiny)) note("b = Slope of regression line")) ///
           xtitle("Fraction STEM") ytitle("Log Median Earnings") graphregion(color(white))
    graph export "$output_path\Ivy_Plus_Earnings_STEM_Scatter.png", replace
restore

* ---------------------------------------------------------------------------
* PART 9: TIER 2 and 3-5 QUARTILE ANALYSIS
* ---------------------------------------------------------------------------
capture drop analysis_group
gen analysis_group = .
replace analysis_group = 2 if tier == 2
replace analysis_group = 35 if inlist(tier, 3, 4, 5)

foreach g in 2 35 {
    if `g' == 2 local group_name "Tier 1 (Other Elite)"
    if `g' == 35 local group_name "Tiers 3-5 (Selective)"
    
    preserve
        keep if analysis_group == `g'
        
        * Regressions
        eststo clear
        eststo: reg ln_k_median pct_stem
        eststo: reghdfe ln_k_median pct_stem, absorb(birth_cohort)
        esttab using "$output_path\STEM_Earnings_Table_Group`g'.tex", replace ///
            booktabs fragment label cells(b(star fmt(3)) se(par fmt(3))) ///
            stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
            title("Earnings vs STEM: `group_name'") mtitles("Simple" "Cohort FE")

        * Graphing Labels
        capture drop cohort_label
        gen cohort_label = ""
        levelsof birth_cohort, local(cohorts)
        foreach c of local cohorts {
            quietly reg ln_k_median pct_stem if birth_cohort == `c'
            local b : display %4.3f _b[pct_stem]
            replace cohort_label = "`c' (b=`b')" if birth_cohort == `c'
        }
        
        separate ln_k_median, by(tier)
        
        if `g' == 2 {
            twoway (scatter ln_k_median2 pct_stem, mcolor(maroon) msize(tiny) msymbol(circle)) ///
                   (lfit ln_k_median pct_stem, lcolor(black) lwidth(medium)), ///
                   by(cohort_label, title("Earnings vs STEM: `group_name'") ///
                      legend(off) note("Tier 1(Other Elite) universities")) ///
                   xtitle("Fraction STEM") ytitle("Log Earnings") graphregion(color(white))
        }
        else {
            twoway (scatter ln_k_median3 pct_stem, mcolor(forest_green) msize(tiny) msymbol(circle)) ///
                   (scatter ln_k_median4 pct_stem, mcolor(dkorange) msize(tiny) msymbol(circle)) ///
                   (scatter ln_k_median5 pct_stem, mcolor(teal) msize(tiny) msymbol(circle)) ///
                   (lfit ln_k_median pct_stem, lcolor(black) lwidth(medium)), ///
                   by(cohort_label, title("Earnings vs STEM: `group_name'") note("Points colored by University Tier")) ///
                   legend(order(1 "Tier 3" 2 "Tier 4" 3 "Tier 5") position(3) size(small)) ///
                   xtitle("Fraction STEM") ytitle("Log Earnings") graphregion(color(white))
        }
        graph export "$output_path\Scatter_Group`g'.png", replace
    restore
}

* ---------------------------------------------------------------------------
* PART 10: SENSITIVITY ANALYSIS (OPTIMIZED IQR METHOD)
* ---------------------------------------------------------------------------
display "Generating Sensitivity Analysis (Dropping Outliers via IQR Method)..."

* Ensure main variables
use "mrc_table3.dta", clear
capture rename cohort birth_cohort
merge 1:1 super_opeid birth_cohort using "$output_path\ipeds_stem_system_clean.dta", keep(1 3) nogenerate
capture gen ln_k_median = log(k_median)

preserve
    * OPTIMIZED OUTLIER CALCULATION - FIXED: Removed nested preserve
    
    * 1. Save current state to tempfile (instead of preserve)
    tempfile main_data_for_iqr
    save `main_data_for_iqr'
    
    * 2. Calculate Quartiles via collapse
    collapse (p25) q1_stem=pct_stem (p75) q3_stem=pct_stem, by(tier birth_cohort)
    tempfile quartiles
    save `quartiles'
    
    * 3. Restore main data and merge
    use `main_data_for_iqr', clear
    merge m:1 tier birth_cohort using `quartiles', assert(3) nogenerate
    
    gen iqr_stem = q3_stem - q1_stem
    gen upper_fence = q3_stem + (1.5 * iqr_stem)
    gen is_outlier = (pct_stem > upper_fence) & !missing(pct_stem)
    
    count if is_outlier
    display "Dropping " r(N) " outlier observations (> 1.5*IQR above Q3)."
    drop if is_outlier
    
    * 10A: IVY PLUS NO OUTLIERS
    * -------------------------
    tempfile data_no_outliers
    save `data_no_outliers'
    
    keep if tier == 1
    
    * FIXED: Check if 'name' exists
    capture confirm variable name
    if _rc != 0 gen name = "Uni " + string(super_opeid)

    replace name = "MIT" if strpos(name, "Massachusetts Institute") > 0
    replace name = "UPenn" if strpos(name, "Pennsylvania") > 0
    replace name = "Columbia" if strpos(name, "Columbia") > 0
    
    * Table
    eststo clear
    eststo: reg ln_k_median pct_stem
    eststo: reghdfe ln_k_median pct_stem, absorb(birth_cohort)
    esttab using "$output_path\Ivy_Plus_STEM_Earnings_Table_NoOutliers.tex", replace ///
        booktabs fragment label cells(b(star fmt(3)) se(par fmt(3))) ///
        stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
        title("Earnings vs STEM (Ivy Plus, No Outliers)") mtitles("Simple" "Cohort FE")
        
    * Graph
    gen cohort_label = ""
    levelsof birth_cohort, local(cohorts)
    foreach c of local cohorts {
        quietly reg ln_k_median pct_stem if birth_cohort == `c'
        local b : display %4.3f _b[pct_stem]
        replace cohort_label = "`c' (b=`b')" if birth_cohort == `c'
    }
    
    separate ln_k_median, by(name) veryshortlabel
    local school_colors "sienna ltblue red forest_green midblue maroon gray dkorange cranberry purple navy black"

    twoway (scatter ln_k_median?* pct_stem, ///
                mcolor(`school_colors') msize(small) msymbol(circle)) ///
           (lfit ln_k_median pct_stem, lcolor(black) lwidth(medium)), ///
           by(cohort_label, title("Earnings vs STEM (Ivy Plus - No Outliers)") ///
              legend(position(3) size(tiny)) note("IQR Outliers removed")) ///
           xtitle("Fraction STEM") ytitle("Log Median Earnings") graphregion(color(white))
    graph export "$output_path\Ivy_Plus_Earnings_STEM_Scatter_NoOutliers.png", replace
    
    * 10B: OTHER TIERS NO OUTLIERS
    * ----------------------------
    foreach g in 2 35 {
        if `g' == 2 local group_name "Tier 2 (Other Elite)"
        if `g' == 35 local group_name "Tiers 3-5 (Selective)"
        
        use `data_no_outliers', clear
        gen analysis_group = .
        replace analysis_group = 2 if tier == 2
        replace analysis_group = 35 if inlist(tier, 3, 4, 5)
        keep if analysis_group == `g'
        
        * Table
        eststo clear
        eststo: reg ln_k_median pct_stem
        eststo: reghdfe ln_k_median pct_stem, absorb(birth_cohort)
        esttab using "$output_path\STEM_Earnings_Table_Group`g'_NoOutliers.tex", replace ///
            booktabs fragment label cells(b(star fmt(3)) se(par fmt(3))) ///
            stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
            title("Earnings vs STEM: `group_name' (No Outliers)") mtitles("Simple" "Cohort FE")
            
        * Graph
        gen cohort_label = ""
        levelsof birth_cohort, local(cohorts)
        foreach c of local cohorts {
            quietly reg ln_k_median pct_stem if birth_cohort == `c'
            local b : display %4.3f _b[pct_stem]
            replace cohort_label = "`c' (b=`b')" if birth_cohort == `c'
        }
        
        if `g' == 2 {
            gen tier2_earnings = ln_k_median if tier == 2
            twoway (scatter tier2_earnings pct_stem, mcolor(maroon) msize(tiny) msymbol(circle)) ///
                   (lfit ln_k_median pct_stem, lcolor(black) lwidth(medium)), ///
                   by(cohort_label, title("`group_name' (No Outliers)") ///
                      legend(off) note("Tier 2 (Other Elite) universities")) ///
                   xtitle("Fraction STEM") ytitle("Log Earnings") graphregion(color(white))
        }
        else {
            gen tier3_earnings = ln_k_median if tier == 3
            gen tier4_earnings = ln_k_median if tier == 4
            gen tier5_earnings = ln_k_median if tier == 5
            
            twoway (scatter tier3_earnings pct_stem, mcolor(forest_green) msize(tiny) msymbol(circle)) ///
                   (scatter tier4_earnings pct_stem, mcolor(dkorange) msize(tiny) msymbol(circle)) ///
                   (scatter tier5_earnings pct_stem, mcolor(teal) msize(tiny) msymbol(circle)) ///
                   (lfit ln_k_median pct_stem, lcolor(black) lwidth(medium)), ///
                   by(cohort_label, title("`group_name' (No Outliers)") ///
                      note("Points colored by University Tier")) ///
                   legend(order(1 "Tier 3" 2 "Tier 4" 3 "Tier 5") position(3) size(small)) ///
                   xtitle("Fraction STEM") ytitle("Log Earnings") graphregion(color(white))
        }
        graph export "$output_path\Scatter_Group`g'_NoOutliers.png", replace
    }
restore

display "Analysis Complete! All outputs saved to: $output_path"

log close