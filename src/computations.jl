# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Computations
# -------------------------------------------------------------------------------------------------------------------------------------------------------------


using DataFrames, RData, CSV, XLSX, LinearAlgebra, Statistics, Intervals

dir = "X:/VIVES/1-Personal/Florian/git/OECD_ICIO/src/"
dir_raw = "C:/Users/u0148308/data/raw/" # location of raw data

# other scripts
include(dir * "functions.jl") # Script with functions to import and transform raw data

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

A = Z ./ repeat(X', N*S) # NS×NS, input coefficients
A .= ifelse.(isnan.(A), 0.0, A) # in case X = 0 (otherwise we cannot compute Leontief inverse since NaN in A)

B = inv(I - A) # NS×NS, Leontief inverse

count(broadcast(in, B*[sum(Y[i,:]) for i in 1:N*S] ./ X, 0.95..1.05) .== 0) # gives number of values lying outside of interval


# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Crosscheck computations with TiVA database: https://stats.oecd.org/Index.aspx?datasetcode=TIVA_2021_C1#
# reporter:
#   - country: AUT (n = 2)
#   - industry: D16 (wood and wood products) (s = 8)
#   - row number: (n-1)*S+s = 1*S+8 = 53
# partner:
#   - country: DEU (n = 13)
#   - industry: D41T43 (construction) (s = 25)
#   - column number: (n-1)*S+s = 12*S+25 = 565
#   - column number: (n-1)*S+s = 12*S+8 = 548 (for imports, i.e. D16 as origin industry)
# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.1 PROD: Production (gross output), USD million
X

# 4.2 VALU: Value added, USD million
W

# 4.3 PROD_VASH: Value added as a share of Gross Output, by industry, percentage
V = W ./ X # NS×1, (row vector in OECD)

# 4.4 EXGR | EXGR_INT | EXGR_FNL: Gross exports, by industry and by partner country, USD million (f.o.b.)
#   - to obtain total => [sum(EXGR[i, :]) for i in 1:N]
EXGR, EXGR_INT, EXGR_FNL = exports(Z, Y, N, S, "country") # N×N
EXGR, EXGR_INT, EXGR_FNL = exports(Z, Y, N, S, "industry") # NS×N

# 4.5. IMGR | IMGR_INT | IMGR_FNL: Gross imports, by industry and by partner country, USD million (f.o.b.)
#   - to obtain total => [sum(IMGR[:, i]) for i in 1:N]
IMGR, IMGR_INT, IMGR_FNL = imports(Z, Y, N, S, "country") # N×N
IMGR_INT, IMGR_FNL = imports(Z, Y, N, S, "industry") # N×NS, N×N

# 4.6. BALGR | BALGR_INT | BALGR_FNL: Gross trade balance, by partner country, USD million (f.o.b.)
EXGR, EXGR_INT, EXGR_FNL = exports(Z, Y, N, S, "country") # N×N
IMGR, IMGR_INT, IMGR_FNL = imports(Z, Y, N, S, "country") # N×N

#   - to obtain total => [sum(BALGR[i, :]) for i in 1:N], [sum(BALGR[:, i]) for i in 1:N]
#   - look at one row: negative/positive => import more than export (trade deficit) / export more than import (trade surplus)
#   - look at one column: positive/negative => import more than export (trade deficit) / export more than import (trade surplus)
BALGR = EXGR .- IMGR' # N×N
BALGR_INT = EXGR_INT .- IMGR_INT' # N×N
BALGR_FNL = EXGR_FNL .- IMGR_FNL' # N×N

# 4.7. EXGRpSH: Gross exports, partner shares, by industry, percentage
EXGR, EXGR_INT, EXGR_FNL = exports(Z, Y, N, S, "industry") # NS×N

#   - total exports by industry
EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S]

EXGRpSH_INT = EXGR_INT ./ repeat(EXGR_TOTAL, 1, N) .* 100 # what to do with NaN?
EXGRpSH_FNL = EXGR_FNL ./ repeat(EXGR_TOTAL, 1, N) .* 100
EXGRpSH = EXGR ./ repeat(EXGR_TOTAL, 1, N) .* 100

all([sum(EXGRpSH[i, :]) for i in 1:N*S] .≈ 100)

# 4.8. IMGRpSH: Gross imports, partner shares %, by industry, percentage (DONT UNDERSTAND!)
IMGR, IMGR_INT, IMGR_FNL = imports(Z, Y, N, S, "country") # N×N

#   - total imports
IMGR_TOTAL = [sum(IMGR[:, i]) for i in 1:N]

IMGRpSH_INT = IMGR_INT ./ repeat(IMGR_TOTAL', N) .* 100 # what to do with NaN?
IMGRpSH_FNL = IMGR_FNL ./ repeat(IMGR_TOTAL', N) .* 100
IMGRpSH = IMGR ./ repeat(IMGR_TOTAL', N) .* 100

all([sum(IMGRpSH[:, i]) for i in 1:N] .≈ 100)