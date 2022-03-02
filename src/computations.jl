# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Computations
# -------------------------------------------------------------------------------------------------------------------------------------------------------------


using DataFrames, RData, CSV, XLSX, LinearAlgebra, Statistics, Intervals

dir = "X:/VIVES/1-Personal/Florian/git/OECD_ICIO/src/"
dir_raw = "C:/Users/u0148308/data/raw/" # location of raw data

# other scripts
include(dir * "import_data.jl") # Script with functions to import and transform raw data

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# OECD rev. 2021
source = "OECD"
revision = "2021"
year = 2015 # specified year
N = 69 # number of countries (originally MEX/CHN twice so 71)
S = 45 # number of industries

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Notes:
#   - Z: NS×NS, intermediate demand matrix
#   - Y: NS×N, final demand matrix
#   - W: NS×1, value added vector (notice: in OECD its a row vector)
#   - X: NS×1, output vector (notice: in OECD its a row vector)

Z, Y, W, X = import_data(dir_raw, source, revision, year)

Z, Y, W, X = remove_reorder(Z, Y, W, X, N, S)

any(Z .< 0.0)
any(Y .< 0.0) # possible to have negative values due to inventory!
any(W .< 0.0)
any(X .< 0.0)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# other basic matrices
V = W ./ X # NS×1, value added to output ratio (notice: in OECD its a row vector)

A = Z ./ repeat(X', N*S) # NS×NS, input coefficients
A .= ifelse.(isnan.(A), 0.0, A) # in case X = 0 (otherwise we cannot compute Leontief inverse since NaN in A)

B = inv(I - A) # NS×NS, Leontief inverse

count(broadcast(in, B*[sum(Y[i,:]) for i in 1:N*S] ./ X, 0.95..1.05) .== 0) # gives number of values lying outside of interval

GRTR_INT, GRTR_FNL, GRTR = trade(Z, Y, N, S, "industry")