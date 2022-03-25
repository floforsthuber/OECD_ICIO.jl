# -------------------------------------------------------------------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------------------------------------------------------------------

function import_data(dir::String, source::String, revision::String, year::Integer)

    if source == "OECD"
        
        if revision == "2021"
            
            file = source * "/" * revision * "/"
            path = ifelse(contains(dir[end-5:end], '.'), dir, dir * file)

            time = 1995:2018
            index = findfirst(time .== year) # get index of specified year

            Z = RData.load(path * "ICIO2021econZ" * ".RData")["ICIO2021econZ"][index,:,:] # intermediate demand
            Y = RData.load(path * "ICIO2021econFD" * ".RData")["ICIO2021econFD"][index,:,:] # final demand
            W = RData.load(path * "ICIO2021econVA" * ".RData")["ICIO2021econVA"][index,:,:] # value added
            X = RData.load(path * "ICIO2021econX" * ".RData")["ICIO2021econX"][index,:,:] # gross output

            println(" ✓ Raw data from $source (rev. $revision) for $year was successfully imported!")

        else
            println(" × The revision - $revision - of $source IO tables is not available!")
        end

    end

    return Z, Y, W, X

end



function remove_reorder(Z::Matrix{Float64}, Y::Matrix{Float64}, W::Matrix{Float64}, X::Matrix{Float64}, N::Integer, S::Integer)

    # merge MX1 and MX2 and substitute for MEX
    # rows
    Z[(N-43)*S+1:(N-42)*S, :] .= Z[(N-43)*S+1:(N-42)*S, :] .+ Z[N*S+1:(N+1)*S, :] .+ Z[(N+1)*S+1:(N+2)*S, :]
    Y[(N-43)*S+1:(N-42)*S, :] .= Y[(N-43)*S+1:(N-42)*S, :] .+ Y[N*S+1:(N+1)*S, :] .+ Y[(N+1)*S+1:(N+2)*S, :]
    W[(N-43)*S+1:(N-42)*S] .= W[(N-43)*S+1:(N-42)*S] .+ W[N*S+1:(N+1)*S] .+ W[(N+1)*S+1:(N+2)*S]
    X[(N-43)*S+1:(N-42)*S] .= X[(N-43)*S+1:(N-42)*S] .+ X[N*S+1:(N+1)*S] .+ X[(N+1)*S+1:(N+2)*S]
    # columns
    Z[:, (N-43)*S+1:(N-42)*S] .= Z[:, (N-43)*S+1:(N-42)*S] .+ Z[:, N*S+1:(N+1)*S] .+ Z[:, (N+1)*S+1:(N+2)*S]
    Y[:, (N-42)] .= Y[:, (N-42)] .+ Y[:, (N+1)] .+ Y[:, (N+2)]
    # added domest trade twice! (actually no double counting because columns/rows are designed to avoid)
    # Z[(N-43)*S+1:(N-42)*S, (N-43)*S+1:(N-42)*S] .= Z[(N-43)*S+1:(N-42)*S, (N-43)*S+1:(N-42)*S] ./ 2
    # Y[(N-43)*S+1:(N-42)*S, (N-42)] .= Y[(N-43)*S+1:(N-42)*S, (N-42)] ./ 2

    # merge CH1 and CH2 and substitute for CHN
    # rows
    Z[(N-24)*S+1:(N-23)*S, :] .= Z[(N-24)*S+1:(N-23)*S, :] .+ Z[(N+2)*S+1:(N+3)*S, :] .+ Z[(N+3)*S+1:(N+4)*S, :]
    Y[(N-24)*S+1:(N-23)*S, :] .= Y[(N-24)*S+1:(N-23)*S, :] .+ Y[(N+2)*S+1:(N+3)*S, :] .+ Y[(N+3)*S+1:(N+4)*S, :]
    W[(N-24)*S+1:(N-23)*S] .= W[(N-24)*S+1:(N-23)*S] .+ W[(N+2)*S+1:(N+3)*S] .+ W[(N+3)*S+1:(N+4)*S]
    X[(N-24)*S+1:(N-23)*S] .= X[(N-24)*S+1:(N-23)*S] .+ X[(N+2)*S+1:(N+3)*S] .+ X[(N+3)*S+1:(N+4)*S]
    # columns
    Z[:, (N-24)*S+1:(N-23)*S] .= Z[:, (N-24)*S+1:(N-23)*S] .+ Z[:, (N+2)*S+1:(N+3)*S] .+ Z[:, (N+3)*S+1:(N+4)*S]
    Y[:, (N-23)] .= Y[:, (N-23)] .+ Y[:, (N+3)] .+ Y[:, (N+4)]
    # added domestic trade twice! (actually no double counting because columns/rows are designed to avoid)
    # Z[(N-24)*S+1:(N-23)*S, (N-24)*S+1:(N-23)*S] .= Z[(N-24)*S+1:(N-23)*S, (N-24)*S+1:(N-23)*S] ./ 2
    # Y[(N-24)*S+1:(N-23)*S, (N-23)] .= Y[(N-24)*S+1:(N-23)*S, (N-23)] ./ 2

    # delete MX1/CH1 and MX2/CH2
    Z = Z[1:N*S, 1:N*S]
    Y = Y[1:N*S, 1:N]
    W = W[1:N*S]
    X = X[1:N*S]

    return Z, Y, W, X

end



function trade(Z::Matrix{Float64}, Y::Matrix{Float64}, N::Integer, S::Integer, dimension::String, flow::String)

    if dimension == "industry"

        # bilateral trade by exporting industry/country and importing country
        #   - remove domestic trade
        GRTR_INT = [sum(Z[i, j:j+S-1]) for i in 1:N*S, j in 1:S:N*S] # NS×N
        GRTR_FNL = copy(Y) # NS×N

        for i in 1:N*S
            GRTR_INT[i, ceil(Int, i/S)] = 0.0
            GRTR_FNL[i, ceil(Int, i/S)] = 0.0
        end
        
    else 

        # bilateral trade by exporting country and importing country
        #   - remove domestic trade
        GRTR_INT = [sum(Z[i:i+S-1, j:j+S-1]) for i in 1:S:N*S, j in 1:S:N*S] # N×N
        GRTR_FNL = [sum(Y[i:i+S-1, j]) for i in 1:S:N*S, j in 1:N] # N×N

        for i in 1:N
            GRTR_INT[i, i] = 0.0
            GRTR_FNL[i, i] = 0.0
        end

    end

    GRTR = GRTR_INT .+ GRTR_FNL


    if flow == "exports"
        return GRTR, GRTR_INT, GRTR_FNL
    else
        return GRTR', GRTR_INT', GRTR_FNL'
    end

end




function exports(Z::Matrix{Float64}, Y::Matrix{Float64}, N::Integer, S::Integer, dimension::String)

    if dimension == "industry"

        # bilateral trade by exporting industry/country and importing country
        #   - remove domestic trade
        EXGR_INT = [sum(Z[i, j:j+S-1]) for i in 1:N*S, j in 1:S:N*S] # NS×N
        EXGR_FNL = copy(Y) # NS×N

        for i in 1:N*S
            EXGR_INT[i, ceil(Int, i/S)] = 0.0
            EXGR_FNL[i, ceil(Int, i/S)] = 0.0
        end
        
    else 

        # bilateral trade by exporting country and importing country
        #   - remove domestic trade
        EXGR_INT = [sum(Z[i:i+S-1, j:j+S-1]) for i in 1:S:N*S, j in 1:S:N*S] # N×N
        EXGR_FNL = [sum(Y[i:i+S-1, j]) for i in 1:S:N*S, j in 1:N] # N×N

        for i in 1:N
            EXGR_INT[i, i] = 0.0
            EXGR_FNL[i, i] = 0.0
        end

    end

    EXGR = EXGR_INT .+ EXGR_FNL

    return EXGR, EXGR_INT, EXGR_FNL

end



function imports(Z::Matrix{Float64}, Y::Matrix{Float64}, N::Integer, S::Integer, dimension::String)

    if dimension == "industry"

        # bilateral trade by exporting industry/country and importing country
        #   - remove domestic trade
        IMGR_INT = [sum(Z[i:i+S-1, j]) for i in 1:S:N*S, j in 1:N*S] # N×NS
        IMGR_FNL = [sum(Y[i:i+S-1, j]) for i in 1:S:N*S, j in 1:N] # N×N

        for i in 1:N*S
            IMGR_INT[ceil(Int, i/S), i] = 0.0
            IMGR_FNL[ceil(Int, i/S), ceil(Int, i/S)] = 0.0
        end
        
        # cannot add up since final demand is not differentiated along industries

        return IMGR_INT, IMGR_FNL

    else 

        # bilateral trade by exporting country and importing country
        #   - remove domestic trade
        IMGR_INT = [sum(Z[i:i+S-1, j:j+S-1]) for i in 1:S:N*S, j in 1:S:N*S] # N×N
        IMGR_FNL = [sum(Y[i:i+S-1, j]) for i in 1:S:N*S, j in 1:N] # N×N

        for i in 1:N
            IMGR_INT[i, i] = 0.0
            IMGR_FNL[i, i] = 0.0
        end

        IMGR = IMGR_INT .+ IMGR_FNL # N×N

        return IMGR, IMGR_INT, IMGR_FNL

    end

end


