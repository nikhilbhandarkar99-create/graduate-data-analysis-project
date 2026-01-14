# Extension of Weinstein (2025): STEM Majors & Recession

## Project Overview
This project is an extension of the analysis found in **Weinstein (2025)**. It investigates the relationship between economic recessions, the composition of STEM majors, and subsequent earnings gaps across different university tiers (Ivy Plus, Elite, and Selective).

The analysis processes raw IPEDS completion data to calculate STEM degree fractions, links this to the original replication package earnings data, and executes Difference-in-Differences (DiD) and Triple-Difference (DDD) regression models.

## Data Requirements
This analysis relies on two primary data sources, which must be configured in the project directory:

### 1. IPEDS Completion Data
* **Source:** Integrated Postsecondary Education Data System (IPEDS).
* **Range:** Years 2002 through 2013.
* **Location:** The script expects files in `../new_extension_data/ipeds_raw/`.
* **Processing:** The script looks for `.dta` or `.csv` files (e.g., `c2002_a.dta`) and identifies STEM degrees based on the NSF definition (CIP codes 11, 14, 15, 26, 27, 40).

### 2. Replication Data
* **Source:** Weinstein (2025) Replication Package.
* **Files:** `mrc_table3.dta` (Main dataset) and a crosswalk file linking OPEIDs to IPEDS UnitIDs.
* **Location:** The script expects files in `./ReplicationPackage/`.

## Analysis Pipeline
The Stata script (`working_replication_extension_final.do`) is organized into 10 logical parts:

1.  **Data Cleaning (Parts 1-3):** Loops through IPEDS data, defines STEM majors, and merges these ratios with the earnings replication data.
2.  **Econometric Analysis (Part 4):**
    * Automatically detects if unemployment shock data is available.
    * **Triple-Difference (DDD):** Executed if shock data permits.
    * **Difference-in-Differences (DiD):** Executed as a fallback default.
3.  **Descriptive Analysis (Parts 6-9):** Generates aggregate trend lines and scatter plots for Ivy Plus, Elite, and Selective tiers.
4.  **Sensitivity Analysis (Part 10):** Performs robustness checks by removing outliers using the Inter-quartile Range (IQR) method and re-running key regressions.

## Key Outputs
All results are automatically saved to the `output/` directory:

* **Regression Tables (.tex):**
    * `STEM_Extension_Results.tex`: Main regression results (Baseline Gap & Mechanism).
    * `Ivy_Plus_STEM_Earnings_Table.tex`: Earnings vs. STEM share (Ivy Plus).
* **Figures (.png):**
    * `STEM_Trends_Graph.png`: Aggregate trends in STEM major share by Tier.
    * `Ivy_Plus_Trends.png`: Line graph for individual Ivy Plus schools.

## Prerequisites & Installation
* **Software:** Stata (Version 14 or higher recommended).
* **Required Packages:** The script automatically checks for and installs the following:
    * `reghdfe`: High-dimensional fixed effects.
    * `ftools`: Faster Stata commands.
    * `coefplot`: Plotting regression coefficients.
    * `estout`: Exporting regression
