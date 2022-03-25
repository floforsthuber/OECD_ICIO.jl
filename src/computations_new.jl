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

EXGR_IDC_i = fill(0.0, N*S, S) # initialize
for c in 1:N
    v_hat = Diagonal(V[(c-1)*S+1:c*S])
    b_offdiag = B[(c-1)*S+1:c*S, (c-1)*S+1:c*S]
    for i in 1:S b_offdiag[i, i] = 0.0 end
    e_tot = [sum(EXGR[i, :]) for i in (c-1)*S+1:c*S]
    for s in 1:S
        e = fill(0.0, S)
        e[s] = e_tot[s]
        EXGR_IDC_i[(c-1)*S+s, :] = v_hat * b_offdiag * e
    end
end

#   - ctry: AUT, industry: D16 indirect domestic value added content to total gross exports from ind: D41T43 => EXGR_IDC_i[53, 25]
EXGR_IDC_i # NS×S

#   - ctry: AUT, industry: D16 indirect domestic value added content to total gross exports => EXGR_IDC[53]
EXGR_IDC = [sum(EXGR_IDC_i[i, :]) for i in 1:N*S] # NS×1

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.7. EXGR_RIM: Re-imported domestic value added content of gross exports, USD million

#   - total domestic value added in gross exports per industry
EXGR_DVA_TOTAL = [sum(EXGR_DVA[i, :]) for i in 1:N*S]

#   - ctry: AUT, industry: D16 re-imported domestic value added content to total gross exports => EXGR_RIM[53]
EXGR_RIM = EXGR_DVA_TOTAL .- EXGR_DDC .- EXGR_IDC

# wrong => no discrepancy?

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.8. EXGR_FVA: Foreign value added content of gross exports, by industry, USD million
#   - EXGR_RIM is included in EXGR_FVA!
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

v_hat = Diagonal(V) # NS×NS
EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1, total exports per industry

EXGR_FVA_all = fill(0.0, N*S, N*S) # initialize

for c in 1:N
    for s in 1:S
        b_column = B[:, (c-1)*S+s] # all input requirements of country: c, industry: s from each other country-industry pair
        b_column[(c-1)*S+1:c*S] .= 0 # all domestic input requirements are set to zero => since captured by EXGR_DVA
        
        fva = v_hat * b_column * EXGR_TOTAL'
        EXGR_FVA_all[(c-1)*S+s, :] .= fva[:, (c-1)*S+s]
    end
end

#   - ctry: AUT, industry: D16 foreign value added content in gross exports => EXGR_FVA[53]
EXGR_FVA = [sum(EXGR_FVA_all[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 foreign value added content in gross exports per partner ctry: DEU => EXGR_FVA_p[53, 13]
EXGR_FVA_p = [sum(EXGR_FVA_all[i, (j-1)*S+1:j*S]) for i in 1:N*S, j in 1:N] # N×NS

any([sum(EXGR_FVA_p[i, :]) for i in 1:N*S] ≈ EXGR_FVA)

#   - ctry: AUT, ind: D16 foreign value added content in gross exports per partner ctry: DEU, ind: D41T43 => EXGR_FVA_all[53, 565]
EXGR_FVA_all # NS×NS

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.9. EXGR_FVASH: Foreign value added share of gross exports, percentage
#   - EXGR_RIM is included in EXGR_FVA!
#   - see 5.8. for EXGR_FVA_all computation
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1, total exports per industry

#   - ctry: AUT percentage share of foreign value added content in gross exports in ind: D16 => EXGR_FVASH[53]
EXGR_FVASH = EXGR_FVA ./ EXGR_TOTAL .* 100 # NS×1, what to do with NaN?

#   - ctry: AUT, ind: D16 percentage points of foreign value added content in gross exports by partner ctry: DEU => EXGR_FVApSH[53, 13]
#       + EXGR_FVApSH[53, 13] percentage points of foreign value added in ctry: AUT, ind: D16 originates in ctry: DEU
#       + EXGR_FVASH[53] = 30% of VA comes is foreign, EXGR_FVApSH[53, 13] = 8 p.p. originate in DEU
#           i.e. EXGR_FVApSH[53, 13]/EXGR_FVASH[53] = 8/30 = 27% of FVA in ctry: AUT, ind: D16 comes from DEU
EXGR_FVApSH = EXGR_FVA_p ./ repeat(EXGR_TOTAL, 1, N) .* 100

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.10. EXGR_TFVAIND Industry foreign value added contribution to gross exports, a as a percentage of total gross exports
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N] # N×1, total exports

#   - ctry: AUT, ind: D16 percentage share of foreign value added content in total gross exports => EXGR_TFVAIND[53]
#       + EXGR_TFVAIND[53] = 0.67 p.p. of foreign value added contained in AUT exports are contained in industry D16
#           i.e. to compare across industries
EXGR_TFVAIND = EXGR_FVA ./ repeat(EXGR_TOTAL, inner=S) .* 100

#   - ctry: AUT percentage share of foreign value added content in total gross exports => EXGR_TFVAIND_c[2]
EXGR_TFVAIND_c = [sum(EXGR_TFVAIND[(i-1)*S+1:i*S]) for i in 1:N]

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 7.1. EXGR_BSCI: Origin of value added in gross exports, USD million
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1, total exports per industry
v_hat = Diagonal(V) # NS×NS, diagonalized value added coefficients

EXGR_BSCI = fill(0.0, N*S, N*S) # initialize
for c in 1:N
    for s in 1:S
        e = fill(0.0, N*S)
        e[(c-1)*S+s] = EXGR_TOTAL[(c-1)*S+s]

        EXGR_BSCI[(c-1)*S+s, :] = v_hat * B * e
    end
end

#   - ctry: AUT, ind: D16 value added in gross exports originating from ctry: DEU, ind: D41T43 => EXGR_BSCI[53, 565]
EXGR_BSCI

#   - EXGR_BSCI gathers all value added information (why not compute other statistics from there?)
#       + domestic value added in ctry: AUT, ind: D16 => sum(EXGR_BSCI[53, 45:90]) ≈ sum(EXGR_DVA[53,:])
#       + direct domestic value added in ctry: AUT, ind: D16 => EXGR_BSCI[53, 53] == EXGR_DDC[53]
#       + indirect domestic value added in ctry: AUT, ind: D16 => sum(EXGR_BSCI[53, [46:52; 54:90]]) == EXGR_IDC[53]
#       + foreign value added in ctry: AUT, ind: D16 => sum(EXGR_BSCI[53, [1:45; 91:N*S]]) == EXGR_FVA[53]

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.11. DEXFVApSH: Backward participation in GVCs, percentage
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N] # N×1, total exports

#   - ctry: AUT value added in total gross exports from ctry: DEU => EXGR_BSCI_c[2, 13]
EXGR_BSCI_c = [sum(EXGR_BSCI[(c-1)*S+1:c*S, (p-1)*S+1:p*S]) for c in 1:N, p in 1:N] # N×N

#   - ctry: AUT percentage share of value added in total gross exports originating from ctry: DEU => DEXFVApSH[2, 13]
#       + DEXFVApSH[2, 13] = 8.3% of value added exports from AUT originates from DEU
DEXFVApSH = EXGR_BSCI_c ./ repeat(EXGR_TOTAL, 1, N) .* 100

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.12. EXGR_DVAFXSH: Domestic value added embodied in foreign exports as share of gross exports, percentage
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N] # N×1, total exports

#   - ctry: AUT, ind: D16 value added in total gross exports from ctry: DEU => EXGR_BSCI_c_i[53, 13]
EXGR_BSCI_c_i = [sum(EXGR_BSCI[i, (p-1)*S+1:p*S]) for i in 1:N*S, p in 1:N] # NS×N

EXGR_DVAFXSH = Float64[] # initialize
for c in 1:N
    va_c = EXGR_BSCI_c_i[:, c] # column gives domestic VA per ctry c in contained in row country-industry
    va_c[(c-1)*S+1:c*S] .= 0.0 # set domestic VA to c's own exports to zero
    for s in 1:S
        va_c_i = va_c[s:S:N*S] # subset to industry i
        share = sum(va_c_i) / EXGR_TOTAL[c] * 100 # sum for total (i.e. WORLD as partner) and divide by c's total exports
        push!(EXGR_DVAFXSH, share)
    end
end

#   - VA originating from ctry: AUT, ind: D16 as percentage share of total exports => EXGR_DVAFXSH[53]
#       + AUT domestic value added content embodied in the gross exports of industry D16 in foreign countries 
#           as a percentage of total gross exports of country AUT

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.13. FEXDVApSH: Forward participation in GVCs, percentage
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "country", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N] # N×1, total exports

#   - ctry: AUT value added in total gross exports from ctry: DEU => EXGR_BSCI_c[2, 13]
EXGR_BSCI_c = [sum(EXGR_BSCI[(c-1)*S+1:c*S, (p-1)*S+1:p*S]) for c in 1:N, p in 1:N] # N×N

#   - ctry: AUT percentage share of domestic value added in total gross exports of ctry: DEU => FEXDVApSH[2, 13]
#       + FEXDVApSH[2, 13] = 1.2% of DEU exports is domestic value added originating in AUT
FEXDVApSH = EXGR_BSCI_c ./ repeat(EXGR_TOTAL', N) .* 100

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.14. EXGR_INTDVASH: Domestic value added in exports of intermediate products, as a share of total gross exports, percentage
#   - same calculation as for 5.1. EXGR_DVA
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - ctry: AUT, industry: D16 domestic value added content of gross exports in intermediate input to ctry: DEU => EXGR_INTDVA[53, 13]
EXGR_INTDVA = fill(0.0, N*S, N) # NS×N, initialize

for c in 1:N
    v = V[(c-1)*S+1:c*S] # V_c
    b = B[(c-1)*S+1:c*S, (c-1)*S+1:c*S] # B_c,c
    exgr = EXGR_INT[(c-1)*S+1:c*S, :] # all exports of country "c"
    for p in 1:N
        for i in 1:S
            e = fill(0.0, S) # initialize zero vector
            e[i] = exgr[i, p] # export value of country "c", industry "i" and partner country "p"
            EXGR_INTDVA[(c-1)*S+i, p] = v'*b*e
        end
    end
end

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1, total industry exports

#   - total domestic value added contained in gross exports intermediate inputs by industry
EXGR_INTDVA_TOTAL = [sum(EXGR_INTDVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 share of domestic value added in gross exports of intermediate inputs as percentage of total industry exports => EXGR_INTDVASH[53]
EXGR_INTDVASH = EXGR_INTDVA_TOTAL ./ EXGR_TOTAL .* 100 # NS×1, what to do with NaN?

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.15. EXGR_FNLDVASH: Domestic value added in exports of final products, as a share of total gross exports, percentage
#   - same calculation as for 5.1. EXGR_DVA and 5.14. EXGR_INTDVA
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

#   - ctry: AUT, industry: D16 domestic value added content of gross final demand exports to ctry: DEU => EXGR_FNLDVA[53, 13]
EXGR_FNLDVA = fill(0.0, N*S, N) # NS×N, initialize

for c in 1:N
    v = V[(c-1)*S+1:c*S] # V_c
    b = B[(c-1)*S+1:c*S, (c-1)*S+1:c*S] # B_c,c
    exgr = EXGR_FNL[(c-1)*S+1:c*S, :] # all exports of country "c"
    for p in 1:N
        for i in 1:S
            e = fill(0.0, S) # initialize zero vector
            e[i] = exgr[i, p] # export value of country "c", industry "i" and partner country "p"
            EXGR_FNLDVA[(c-1)*S+i, p] = v'*b*e
        end
    end
end

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1, total industry exports

#   - total domestic value added contained in gross final demand exports by industry
EXGR_FNLDVA_TOTAL = [sum(EXGR_FNLDVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 share of domestic value added in gross exports of final demand as percentage of total industry exports => EXGR_FNLDVASH[53]
EXGR_FNLDVASH = EXGR_FNLDVA_TOTAL ./ EXGR_TOTAL .* 100 # NS×1, what to do with NaN?

any(EXGR_INTDVASH .+ EXGR_FNLDVASH .== EXGR_DVASH)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.16. EXGR_INTDVApSH: Domestic value added in exports of intermediate products, partner shares, percentage

#   - total domestic value added contained in gross exports by industry
EXGR_INTDVA_TOTAL = [sum(EXGR_INTDVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 domestic value added in gross exports of intermediate inputs to ctry: DEU 
#           as percentage of total industry domestic value added exports of intermediate inputs => EXGR_INTDVApSH[53,13]
#       + EXGR_INTDVApSH[53,13] = 19% of domestic value added of intermediate input exports from AUT in D16 go to DEU
EXGR_INTDVApSH = EXGR_INTDVA ./ repeat(EXGR_INTDVA_TOTAL, 1, N) .* 100 # NS×N, what to do with NaN?

EXGR_INTDVApSH .= ifelse.(isnan.(EXGR_INTDVApSH), 0.0, EXGR_INTDVApSH)
count([sum(EXGR_INTDVApSH[i,:]) for i in 1:N*S] .≈ 100.0)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.16.1 EXGR_FNLDVApSH: Domestic value added in exports of final products, partner shares, percentage

#   - total domestic value added contained in gross exports by industry
EXGR_FNLDVA_TOTAL = [sum(EXGR_FNLDVA[i, :]) for i in 1:N*S] # NS×1

#   - ctry: AUT, industry: D16 domestic value added in gross exports of final products to ctry: DEU 
#           as percentage of total industry domestic value added exports of final products => EXGR_FNLDVApSH[53,13]
#       + EXGR_FNLDVApSH[53,13] = 38% of domestic value added of final product exports from AUT in D16 go to DEU
EXGR_FNLDVApSH = EXGR_FNLDVA ./ repeat(EXGR_FNLDVA_TOTAL, 1, N) .* 100 # NS×N, what to do with NaN?

EXGR_FNLDVApSH .= ifelse.(isnan.(EXGR_FNLDVApSH), 0.0, EXGR_FNLDVApSH)
count([sum(EXGR_FNLDVApSH[i,:]) for i in 1:N*S] .≈ 100.0)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.19. IMGR_DVA: Domestic value added embodied in gross imports, USD million
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "industry", "imports") # N×NS

#   - ctry: AUT domestic value added content of gross imports from ctry: DEU, ind: D16 => IMGR_DVA[2, 548]
IMGR_DVA = fill(0.0, N, N*S) # NS×N, initialize

for c in 1:N
    v = V[(c-1)*S+1:c*S] # V_c
    for p in 1:N
        b = B[(c-1)*S+1:c*S, (p-1)*S+1:p*S] # B_c,p
        imgr = Diagonal(IMGR[c, (p-1)*S+1:p*S])
        IMGR_DVA[c, (p-1)*S+1:p*S] = v'*b*imgr
    end
end

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.20. IMGR_DVASH: Domestic value added share of gross imports, percentage
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "industry", "imports") # N×NS

#   - ctry: AUT share of domestic value added in gross imports from ctry: DEU, ind: 16 => IMGR_DVASH[2, 548]
IMGR_DVASH = IMGR_DVA ./ IMGR .* 100 # N×NS, what to do with NaN? (i.e. domestic va imported from own ctry)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.21. REII: Re-exported intermediate imports, USD million
EXGR, EXGR_INT, EXGR_FNL = trade(Z, Y, N, S, "industry", "exports") # NS×N

EXGR_TOTAL = [sum(EXGR[i, :]) for i in 1:N*S] # NS×1, total industry exports

REII_p = fill(0.0, N*S, N)

for c in 1:N
    for p in 1:N
        a = A[(p-1)*S+1:p*S, (c-1)*S+1:c*S]
        #for i in 1:S a[i, i] = 0 end # written in TiVA guide but not true
        e = EXGR_TOTAL[(c-1)*S+1:c*S]
        b = B[(c-1)*S+1:c*S, (c-1)*S+1:c*S]
        REII_p[(c-1)*S+1:c*S, p] = a*b*e
    end
end

#   - Total intermediate products imported in ctry: AUT, ind: D16 originated from ctry: DEU => REII_p[53, 13]
REII_p # NS×N

REII = copy(REII_p)
for c in 1:N*S
    REII[c, ceil(Int, c/S)] = 0.0 # set all domestic contributions to zero
end

#   - Total intermediate products absorbed in ctry: AUT, ind: D16 originated from all foreign countries => REII_p[53]
#       + sum(REII_p[53, :]) - REII_p[53, 2] ≈ REII[53]
REII = [sum(REII[i, :]) for i in 1:N*S] # NS×1

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5.22. IMGRINT_REII: Re-exported intermediate imports as a % of total intermediate imports, percentage
#   - ctry: DEU imports from ctry: AUT, industry: D16 => IMGR[13,53]
IMGR, IMGR_INT, IMGR_FNL = trade(Z, Y, N, S, "industry", "imports") # N×NS

IMGR_INT_TOTAL = [sum(IMGR_INT[i, s:S:N*S]) for i in 1:N, s in 1:S] # N×S, total intermediate industry imports

#   - ctry: AUT, ind: D16 re-exported intermediate imports as a share of total intermediate imports from all foreign countries => IMGRINT_REII[53]
IMGRINT_REII = REII ./ reshape(IMGR_INT_TOTAL', N*S) .* 100 # NS×1

#   - ctry: AUT, ind: D16 re-exported intermediate imports as a share of total intermediate imports from ctry: DEU => IMGRINT_REII_p[53, 13]
IMGRINT_REII_p = REII_p ./ IMGR_INT' .* 100 # NS×N, what to do with Inf?

IMGRINT_REII_p .= ifelse.(isinf.(IMGRINT_REII_p), 0.0, IMGRINT_REII_p)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 6.1. FFD_DVA: Domestic value added embodied in foreign final demand, USD million
v_hat = Diagonal(V)
FD = copy(Y)

#   - Value added originating in ctry:AUT, ind: D16 embodied in final demand of ctry: DEU => FFD_DVA[53, 13]
FFD_DVA = v_hat * B * FD # NS×N

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 6.2. FFD_DVApSH: Domestic value added embodied in foreign final demand, partner shares, percentage
FFD_DVA_c = copy(FFD_DVA)
for c in 1:N*S
    FFD_DVA_c[c, ceil(Int, c/S)] = 0.0 # do not count domestic value added to domestic FD in total
end
FFD_DVA_TOTAL = [sum(FFD_DVA_c[i, :]) for i in 1:N*S] # NS×1

#   - Value added originating in ctry:AUT, ind: D16 embodied in final demand of ctry: DEU 
#       as percentage of total domestic value added originating in ctry: AUT, ind: D16 demanded abroad => FFD_DVApSH[53, 13]
FFD_DVApSH = FFD_DVA_c ./ repeat(FFD_DVA_TOTAL, 1, N) .* 100 # NS×N, what to do with NaN?

count([sum(FFD_DVApSH[i, :]) for i in 1:N*S] .≈ 100)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 6.3. VALU_FFDDVA: Domestic value added embodied in foreign final demand as a % of total value added, percentage
VALU = copy(W) # NS×1, industry value added

FFD_DVA_c = copy(FFD_DVA)
for c in 1:N*S
    FFD_DVA_c[c, ceil(Int, c/S)] = 0.0 # do not count domestic value added to domestic FD in total
end

#   - Domestic value added from ctry: AUT, ind: D16 embodied in foreign final demand in ctry: DEU 
#       as percentage of total value added of ctry: AUT, ind: D16 => VALU_FFDDVA_p[53, 13]
VALU_FFDDVA_p = FFD_DVA_c ./ repeat(VALU, 1, N) .* 100


#   - Domestic value added from ctry: AUT, ind: D16 embodied in total foreign final demand
#       as percentage of total value added of ctry: AUT, ind: D16 => VALU_FFDDVA[53]
VALU_FFDDVA = [sum(VALU_FFDDVA_p[i, :]) for i in 1:N*S]

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# 6.4. DFD_FVA: Foreign value added embodied in domestic final demand, USD million

DFD_FVA = FFD_DVA'