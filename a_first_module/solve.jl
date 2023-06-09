# imports 
using DifferentialEquations                                          # for ODEProblem and solve
using Plots                                                          # for plot
using StaticArrays                                                   # for @SVector 
using Parameters                                                     # for @with_kw


"""
    Modeling(etat0,p,tspan,pas,f)

Create a type Modeling that contains all parameters of the problem.
"""
@with_kw struct Modeling
    etat0::Union{SVector{1,Float64},SVector{2,Float64}}              # etat0 is a vector which size is 1 or 2
    p::Vector{Float64}
    tspan::Tuple{Float64,Float64}
    pas::Float64
    f::Function
end

"""
    simule(mod, affiche;kwargs...)

Computes then shows the solution of the ODE either in a plot or in a vector.
"""
function simule(mod::Modeling, plot=false; kwargs...)
    mod_prob = ODEProblem(mod.f, mod.etat0, mod.tspan, mod.p, saveat=mod.pas)
    mod_sol = solve(mod_prob)
    if plot
        Plots.plot(mod_sol; kwargs...)
    else
        mod_sol
    end
end