# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Computations
# -------------------------------------------------------------------------------------------------------------------------------------------------------------


using DataFrames, CSV, XLSX, LinearAlgebra, Statistics, StatFiles

dir = "X:/VIVES/1-Personal/Florian/git/OECD_ICIO/src/"
dir_raw = "C:/Users/u0148308/Dropbox/STORE/3. GVCs/tasks/task4_MRIO_to_WIOD/output/" # location of raw data

# other scripts
include(dir * "functions.jl") # Script with functions to import and transform raw data

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

N = 43 + 3 # 43 countries + 3 regions of BE
S = 55 # industries

# Notes:
#   - import data in long format and reshape => far quicker!

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Intermediate demand
df = DataFrame(StatFiles.load(dir_raw * "MRIO_WIOT_isic4_" * "IG" * ".dta"))
sort!(df)
df.ID = df.use_country .* "_" .* df.use_isic
df = unstack(df[:, Not([:use_country, :use_isic])], :ID, :value)
Z = Matrix(df[:, 3:end]) # NS×NS

# Notes
#   - missing values in Z => transform to zeros instead
any(ismissing.(Z)) # check for missing values
Z .= ifelse.(ismissing.(Z), 0.0, Z)
Z = Float64.(Z)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Final demand
df = DataFrame(StatFiles.load(dir_raw * "MRIO_WIOT_isic4_" * "FD" * ".dta"))
sort!(df)
df.ID = df.use_country .* "_" .* df.use_isic
df = unstack(df[:, Not([:use_country, :use_isic])], :ID, :value)
Y = Matrix(df[:, 3:end])

any(ismissing.(Y)) # check for missing values

Y = [sum(Y[i, (j-1)*4+1:j*4]) for i in 1:N*S, j in 1:N] # NS×N, sum final demand components

# Notes:
#   - some entries of Y are negative due to inventories
#       + inventory adjustment as in Antras and Chor (2018)?
any(Y .< 0.0) # check for negative values

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Value added
df = DataFrame(StatFiles.load(dir_raw * "MRIO_WIOT_isic4_" * "VA" * ".dta"))
sort!(df)
df = unstack(df, :supply_isic, :value)
transform!(df, [:TAX,:VA] => ByRow((t, v) -> t + v) => :NET)
W = Float64.(df.VA) # NS×1

# Notes:
#   - check wether we should use VA or NET?

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Gross output
X_1 = W .+ [sum(Z[:, j]) for j in 1:N*S] # NS×1, gross output computed from intermediate demand imports and VA
X_2 = [sum(Z[i, :]) + sum(Y[i, :]) for i in 1:N*S] # NS×1, gross output computed from intermediate and final demand exports

# Notes:
#   - X_1 and X_2 are pretty different
X = copy(X_2)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Gross domestic product
GDP = [sum(W[(i-1)*S+1:i*S]) for i in 1:N] # N×1, sum of value added per country

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Domar weights
DW = X ./ repeat(GDP, inner=S) # NS×1
DW_WORLD = X ./ sum(GDP) # NS×1

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Technical coefficients
A = Z ./ repeat(X', N*S) # NS×NS, input coefficients
any(isnan.(A))
A .= ifelse.(isnan.(A), 0.0, A) # in case X = 0 (otherwise we cannot compute Leontief inverse since NaN in A)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Leontief inverse
L = inv(I - A) # NS×NS, Leontief inverse
any(isnan.(L))
any(isinf.(L))

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Total requirements matrix
L * Z # NS×NS

# -------------------------------------------------------------------------------------------------------------------------------------------------------------

# Country-industry final demand multipliers
FD_multi = [sum(L[(i-1)*S+1:i*S, j]) for i in 1:N, j in 1:N*S] # N×NS
FD_multi = reshape(FD_multi', (S, N*N)) # S×NN

# -------------------------------------------------------------------------------------------------------------------------------------------------------------


