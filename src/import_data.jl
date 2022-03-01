
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

    # remove China/Mexico second entry and move ROW to the end of the table
    n_Z = [1:(N-3)*S; (N-2)*S+1:(N-1)*S; N*S+1:(N+1)*S; (N-3)*S+1:(N-2)*S] # reorder to have MEX, CHN, ROW
    n_Y = [1:(N-3); (N-2)+1:(N-1); N+1:(N+1); (N-3)+1:(N-2)]

    # n_y = 6 # number of final demand components
    # n_Y = [1:(N-3)*n_y; (N-2)*n_y+1:(N-1)*n_y; N*n_y+1:(N+1)*n_y; (N-3)*n_y+1:(N-2)*n_y] # if Y has individual final demand components

    Z = Z[n_Z, n_Z]
    Y = Y[n_Z, n_Y]
    W = W[n_Z]
    X = X[n_Z]

    return Z, Y, W, X

end


