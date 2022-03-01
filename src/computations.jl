# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Computations
# -------------------------------------------------------------------------------------------------------------------------------------------------------------


using DataFrames, RData, CSV, XLSX, LinearAlgebra, Statistics

dir = "X:/VIVES/1-Personal/Florian/git/OECD_ICIO/src/"
dir_raw = "C:/Users/u0148308/data/raw/" # location of raw data

# other scripts
include(dir * "import_data.jl") # Script with functions to import and transform raw data

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# OECD rev. 2021
source = "OECD"
revision = "2021"
year = 1995 # specified year
N = 69 # number of countries 
S = 45 # number of industries

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

Z, Y, W, X = import_data(dir_raw, source, revision, year, N, S)

Z, Y, W, X = remove_reorder(Z, Y, W, X, N, S)