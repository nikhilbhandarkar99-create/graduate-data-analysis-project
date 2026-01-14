# Extension of Weinstein (2025): STEM Majors & Recession

## Project Overview
[cite_start]This project is an extension of the analysis found in **Weinstein (2025)**[cite: 1, 5]. [cite_start]It investigates the relationship between economic recessions, the composition of STEM majors, and subsequent earnings gaps across different university tiers (Ivy Plus, Elite, and Selective)[cite: 6].

[cite_start]The analysis processes raw IPEDS completion data to calculate STEM degree fractions, links this to the original replication package earnings data, and executes Difference-in-Differences (DiD) and Triple-Difference (DDD) regression models[cite: 7].

## Data Requirements
[cite_start]This analysis relies on two primary data sources, which must be configured in the project directory[cite: 33]:

### 1. IPEDS Completion Data
* **Source:** Integrated Postsecondary Education Data System (IPEDS).
* [cite_start]**Range:** Years 2002 through 2013[cite: 36].
* [cite_start]**Processing:** The script looks for `.dta` or `.csv` files (e.g., `c2002_a.dta`) to identify STEM degrees based on the NSF definition (CIP codes 11, 14, 15, 26, 27, 40)[cite: 35, 40, 80].

### 2. Replication Data
* **Source:** Weinstein (2025) Replication Package.
* [cite_start]**Files:** `mrc_table3.dta` (Main dataset) and a crosswalk file linking OPEIDs to IPEDS UnitIDs[cite: 46, 47].

## Analysis Pipeline
[cite_start]The Stata script (`working_replication_extension_final.do`) is organized into 10 logical parts[cite: 52]:

1.  [cite_start]**Data Cleaning (Parts 1-3):** Loops through IPEDS data, defines STEM majors, and merges these ratios with the earnings replication data[cite: 53].
2.  **Econometric Analysis (Part 4):**
    * [cite_start]Automatically detects if unemployment shock data is available[cite: 55].
    * [cite_start]**Triple-Difference (DDD):** Executed if shock data permits[cite: 57].
    * [cite_start]**Difference-in-Differences (DiD):** Executed as a fallback default[cite: 57].
3.  [cite_start]**Descriptive Analysis (Parts 6-9):** Generates aggregate trend lines and scatter plots for Ivy Plus, Elite, and Selective tiers[cite: 58].
4.  [cite_start]**Sensitivity Analysis (Part 10):** Performs robustness checks by removing outliers using the Inter-quartile Range (IQR) method and re-running key regressions[cite: 59].

## Key Outputs
[cite_start]All results are automatically saved to the `output/` directory[cite: 61]:

* **Regression Tables (.tex):**
    * [cite_start]`STEM_Extension_Results.tex`: Main regression results (Baseline Gap & Mechanism)[cite: 65].
    * [cite_start]`Ivy_Plus_STEM_Earnings_Table.tex`: Earnings vs. STEM share (Ivy Plus)[cite: 65].
* **Figures (.png):**
    * [cite_start]`STEM_Trends_Graph.png`: Aggregate trends in STEM major share by Tier[cite: 67].
    * [cite_start]`Ivy_Plus_Trends.png`: Line graph for individual Ivy Plus schools[cite: 67].

## Prerequisites & Installation
* [cite_start]**Software:** Stata (Version 14 or higher recommended)[cite: 11].
* [cite_start]**Required Packages:** The script automatically checks for and installs the following[cite: 13]:
    * [cite_start]`reghdfe`: High-dimensional fixed effects[cite: 15].
    * [cite_start]`ftools`: Faster Stata commands[cite: 16].
    * [cite_start]`coefplot`: Plotting regression coefficients[cite: 17].
    * [cite_start]`estout`: Exporting regression tables[cite: 18].

## Configuration
[cite_start]To replicate this analysis, you must update the `user_root` variable in `working_replication_extension_final.do` (Lines 20-30) to match your local project directory path[cite: 22, 23].

## Author
[cite_start]**Nikhil Bhandarkar** [cite: 2]
[cite_start]*Date: December 9, 2025* [cite: 3]
