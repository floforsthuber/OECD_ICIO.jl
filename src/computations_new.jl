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
year = 2018 # specified year
N = 67 # number of countries (originally MEX/CHN three times so 71)
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

any(iszero.(Z)) # will introduce NaN when used as divisor!
any(iszero.(Y)) # what to do in this case?
any(iszero.(W))
any(iszero.(X))

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# other basic matrices
A = Z ./ repeat(X', N*S) # NS×NS, input coefficients
any(isnan.(A))
A .= ifelse.(isnan.(A), 0.0, A) # in case X = 0 (otherwise we cannot compute Leontief inverse since NaN in A)

B = inv(I - A) # NS×NS, Leontief inverse
any(isnan.(B))

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

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.2 VALU: Value added, USD million
W

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.3 PROD_VASH: Value added as a share of Gross Output, by industry, percentage
V = W ./ X # NS×1, (row vector in OECD)
any(isnan.(V))
V .= ifelse.(isnan.(V), 1.0, V) # in case X = 0

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.4 EXGR | EXGR_INT | EXGR_FNL: Gross exports, by industry and by partner country, USD million (f.o.b.)
#   - to obtain total => [sum(EXGR[i, :]) for i in 1:N]
#   - ctry: AUT exports to ctry: DEU => EXGR[2,13]
#   - ctry: AUT, industry: D16 exports to ctry: DEU => EXGR[53,13]
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # N×N
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.5. IMGR | IMGR_INT | IMGR_FNL: Gross imports, by industry and by partner country, USD million (f.o.b.)
#   - to obtain total => [sum(IMGR[:, i]) for i in 1:N]
#   - ctry: DEU imports from ctry: AUT => IMGR[13,2]
#   - ctry: DEU imports from ctry: AUT, industry: D16 => IMGR[13,53]
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "country", "imports") # N×N
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "industry", "imports") # N×NS

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.6. BALGR | BALGR_INT | BALGR_FNL: Gross trade balance, by partner country, USD million (f.o.b.)
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # N×N
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "country", "imports") # N×N

#   - to obtain total => [sum(BALGR[i, :]) for i in 1:N], [sum(BALGR[:, i]) for i in 1:N]
#   - look at one row: negative/positive => import more than export (trade deficit) / export more than import (trade surplus)
#   - look at one column: positive/negative => import more than export (trade deficit) / export more than import (trade surplus)
BALGR = EXGR .- IMGR # N×N
BALGR_INT = EXGR_INT .- IMGR_INT # N×N
BALGR_FNL = EXGR_FNL .- IMGR_FNL # N×N

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.6.1 BALGR | BALGR_INT | BALGR_FNL: Gross trade balance, by partner country and by industry, USD million (f.o.b.)
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "industry", "imports") # N×NS

#   - ctry: AUT, industry: D16 exports to ctry: DEU => EXGR[53,13] = EXGR[(n_r-1)*S+s, n_c]
#   - ctry: AUT imports from ctry: DEU, industry: D16 => IMGR[2,548] = IMGR[n_r, (n_c-1)*S+s]
#       + trade balance form perspective of AUT with DEU in industry D16 => BALGR[2, 13, 8] = BALGR[n_r, n_c, s]

BALGR = [EXGR[(n_r-1)*S+s, n_c] - IMGR[n_r, (n_c-1)*S+s] for n_r in 1:N, n_c in 1:N, s in 1:S]
BALGR_INT = [EXGR_INT[(n_r-1)*S+s, n_c] - IMGR_INT[n_r, (n_c-1)*S+s] for n_r in 1:N, n_c in 1:N, s in 1:S]
BALGR_FNL = [EXGR_FNL[(n_r-1)*S+s, n_c] - IMGR_FNL[n_r, (n_c-1)*S+s] for n_r in 1:N, n_c in 1:N, s in 1:S]

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.7. EXGRpSH: Gross exports, partner shares, by industry, percentage
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - total exports by industry
EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S]

#   - ctry: AUT, industry: D16 export to ctry: DEU as percentage of total industry exports => EXGRpSH[53,13]
EXGRpSH = EXGR ./ repeat(EXGR_TOTAL, 1, N) .* 100
EXGRpSH_INT = EXGR_INT ./ repeat(EXGR_TOTAL, 1, N) .* 100 # what to do with NaN?
EXGRpSH_FNL = EXGR_FNL ./ repeat(EXGR_TOTAL, 1, N) .* 100

all([sum(EXGRpSH[i, :]) for i in 1:N] .≈ 100) # NaN still in there!
all([sum(EXGRpSH_INT[i, :]) .+ sum(EXGRpSH_FNL[i, :]) for i in 1:N] .≈ [sum(EXGRpSH[i, :]) for i in 1:N])

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.7.1 EXGRpSH: Gross exports, partner shares, percentage
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # NS×N

#   - total exports by industry
EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N]

#   - ctry: AUT, industry: D16 exports to ctry: DEU as percentage of total exports => EXGRpSH[2,13]
EXGRpSH = EXGR ./ repeat(EXGR_TOTAL, 1, N) .* 100
EXGRpSH_INT = EXGR_INT ./ repeat(EXGR_TOTAL, 1, N) .* 100 # what to do with NaN?
EXGRpSH_FNL = EXGR_FNL ./ repeat(EXGR_TOTAL, 1, N) .* 100

all([sum(EXGRpSH[i, :]) for i in 1:N] .≈ 100) # NaN still in there!
all([sum(EXGRpSH_INT[i, :]) .+ sum(EXGRpSH_FNL[i, :]) for i in 1:N] .≈ [sum(EXGRpSH[i, :]) for i in 1:N])

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.8. IMGRpSH: Gross imports, partner shares, by industry, percentage
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "industry", "imports") # N×NS

#   - total imports
IMGR_TOTAL = [sum(IMGR[i, :]) for i in 1:N]

#   - ctry: AUT imports from ctry: DEU, industry: D16 as percentage of total imports => IMGRpSH[2,548]
#       + notice difference here to exports => percentage of total industry exports vs percentage of total imports
IMGRpSH = IMGR ./ repeat(IMGR_TOTAL, 1, N*S) .* 100
IMGRpSH_INT = IMGR_INT ./ repeat(IMGR_TOTAL, 1, N*S) .* 100 
IMGRpSH_FNL = IMGR_FNL ./ repeat(IMGR_TOTAL, 1, N*S) .* 100


all([sum(IMGRpSH[i, :]) for i in 1:N] .≈ 100)
all([sum(IMGRpSH_INT[i, :]) .+ sum(IMGRpSH_FNL[i, :]) for i in 1:N] .≈ [sum(IMGRpSH[i, :]) for i in 1:N])

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4.8.1 IMGRpSH: Gross imports, partner shares, percentage
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "country", "imports") # N×NS

#   - total imports
IMGR_TOTAL = [sum(IMGR[i, :]) for i in 1:N]

#   - ctry: AUT imports from ctry: DEU as percentage of total imports  => IMGRpSH[2,13]
IMGRpSH = IMGR ./ repeat(IMGR_TOTAL, 1, N) .* 100
IMGRpSH_INT = IMGR_INT ./ repeat(IMGR_TOTAL, 1, N) .* 100
IMGRpSH_FNL = IMGR_FNL ./ repeat(IMGR_TOTAL, 1, N) .* 100

all([sum(IMGRpSH[i, :]) for i in 1:N] .≈ 100)
all([sum(IMGRpSH_INT[i, :]) .+ sum(IMGRpSH_FNL[i, :]) for i in 1:N] .≈ [sum(IMGRpSH[i, :]) for i in 1:N])

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.1. EXGR_DVA: Domestic value added content of gross exports, USD million
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - ctry: AUT, industry: D16 domestic value added content of gross exports to ctry: DEU => EXGR_DVA[53, 13]
EXGR_DVA = fill(0.0, N*S, N) # NS×N, initialize

for c in 1:N
    v = V[(c-1)*S+1:c*S] # V_c
    b = B[(c-1)*S+1:c*S, (c-1)*S+1:c*S] # B_c,c
    exgr = EXGR[(c-1)*S+1:c*S, :] # all exports of country "c"
    for p in 1:N
        for i in 1:S
            e = fill(0.0, S) # initialize zero vector
            e[i] = exgr[i, p] # export value of country "c", industry "i" and partner country "p"
            EXGR_DVA[(c-1)*S+i, p] = v'*b*e
        end
    end
end

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.2. EXGR_DVASH: Domestic value added share of gross exports, percentage
#   - for EXGR_DVA computation look refer to 5.1.

EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - total exports by industry
EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1

#   - total domestic value added contained in gross exports by industry
EXGR_DVA_TOTAL = [sum(EXGR_DVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 share of domestic value added as percentage of total industry exports => EXGR_DVASH[53]
EXGR_DVASH = EXGR_DVA_TOTAL ./ EXGR_TOTAL .* 100 # NS×1, what to do with NaN?

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.3. EXGR_TDVAIND: Industry domestic value added contribution to gross exports, as a percentage of total gross exports
#   - for EXGR_DVA computation look refer to 5.1.
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - total exports
EXGR_TOTAL = [sum(EXGR[(i-1)*S+1:i*S, :]) for i in 1:N] # N×1

#   - total domestic value added contained in gross exports by industry
EXGR_DVA_TOTAL = [sum(EXGR_DVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 share of domestic value added as percentage of total exports => EXGR_TDVAIND[53]
EXGR_TDVAIND = EXGR_DVA_TOTAL ./ repeat(EXGR_TOTAL, inner=S) .* 100 # NS×1, what to do with NaN?

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.4. EXGR_DVApSH: Domestic value added in gross exports, partner shares, percentage
#   - for EXGR_DVA computation look refer to 5.1.
#   - same as 5.2. but now on the differentiated along partners
#   - [sum(EXGR_DVApSH[i, :]) for i in 1:N*S] .== EXGR_DVASH

EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - total domestic value added contained in gross exports by industry
EXGR_DVA_TOTAL = [sum(EXGR_DVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 domestic value added in exports to ctry: DEU as percentage of total industry domestic value added exports => EXGR_DVApSH[53,13]
#       + 20% of domestic value exported from AUT in D16 go to DEU
EXGR_DVApSH = EXGR_DVA ./ repeat(EXGR_DVA_TOTAL, 1, N) .* 100 # NS×N, what to do with NaN?

EXGR_DVApSH .= ifelse.(isnan.(EXGR_DVApSH), 0.0, EXGR_DVApSH)

[sum(EXGR_DVApSH[i,:]) for i in 1:N*S] .≈ 100.0

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.5. EXGR_DDC: Direct domestic industry value added content of gross exports, USD million
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

EXGR_DDC = Vector{Float64}[] # initialize
for c in 1:N
    v_hat = Diagonal(V[(c-1)*S+1:c*S])
    b_diag = Diagonal(B[(c-1)*S+1:c*S, (c-1)*S+1:c*S])
    e = [sum(EXGR[i, :]) for i in (c-1)*S+1:c*S]
    push!(EXGR_DDC, v_hat * b_diag * e)
end

#   - ctry: AUT, industry: D16 direct domestic value added content to total gross exports => EXGR_DDC[53]
EXGR_DDC = reduce(vcat, EXGR_DDC) # NS×1, collapse vector

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.6. EXGR_IDC: Indirect domestic content of gross exports (originating from domestic intermediates), USD million
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

EXGR_IDC = Vector{Float64}[] # initialize
for c in 1:N
    v_hat = Diagonal(V[(c-1)*S+1:c*S])
    
    b_offdiag = B[(c-1)*S+1:c*S, (c-1)*S+1:c*S]
    for i in 1:S b_offdiag[i, i] = 0.0 end
    
    e = [sum(EXGR[i, :]) for i in (c-1)*S+1:c*S]
    push!(EXGR_IDC, v_hat * b_offdiag * e)
end

#   - ctry: AUT, industry: D16 indirect domestic value added content to total gross exports => EXGR_IDC[53]
EXGR_IDC = reduce(vcat, EXGR_IDC) # NS×1, collapse vector

# not correct!