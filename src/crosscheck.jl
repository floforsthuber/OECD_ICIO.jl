# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Crosscheck
# -------------------------------------------------------------------------------------------------------------------------------------------------------------


using DataFrames, RData, CSV, XLSX, LinearAlgebra, Statistics, Intervals

dir = "X:/VIVES/1-Personal/Florian/git/OECD_ICIO/src/"
dir_raw = "C:/Users/u0148308/data/raw/" # location of raw data


year = "2018"
path = dir_raw * "OECD/2021/df_tiva_" * year * ".csv"
df = CSV.read(path, DataFrame)

cols_string = names(df)[names(df) .!= "VALUE"]
transform!(df, cols_string .=> ByRow(string), renamecols=false)
transform!(df, :VALUE => ByRow(Float64), renamecols=false)
df.DECLARANT_LAB .= ifelse.(df.DECLARANT_LAB .== "European Union (27 countries)", "European Union", df.DECLARANT_LAB)


a = subset(df, :DECLARANT_ISO => ByRow(x -> x == "AUT"), :IND => ByRow(x -> x == "D16"),
     :VAR => ByRow(x -> x in ["EXGR_DVASH", "EXGR_TDVAIND"]))

a = subset(df, :DECLARANT_ISO => ByRow(x -> x == "AUT"), :IND => ByRow(x -> x == "D16"),
     :VAR => ByRow(x -> x in ["EXGR_DVASH", "EXGR_TDVAIND"]))

     a = subset(df, :DECLARANT_ISO => ByRow(x -> x == "AUT"), :PARTNER_ISO => ByRow(x -> x == "DEU"), :IND => ByRow(x -> x == "D16"),
     :VAR => ByRow(x -> x in ["EXGR_DVAPSH"]))

     a = subset(df, :DECLARANT_ISO => ByRow(x -> x == "DEU"), :PARTNER_ISO => ByRow(x -> x == "AUT"), :IND => ByRow(x -> x == "D16"),
     :VAR => ByRow(x -> x in ["EXGR_DVAPSH"]))

     a = subset(df, :DECLARANT_ISO => ByRow(x -> x == "AUT"), :IND => ByRow(x -> x == "D16"),
     :VAR => ByRow(x -> x in ["EXGR_IDC"]))