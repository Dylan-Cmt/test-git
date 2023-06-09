using Revise, ForwardDiff, Parameters, Setfield, Plots, LinearAlgebra
using BifurcationKit
const BK = BifurcationKit

# sup norm
norminf(x) = norm(x, Inf)


################################## Problem setting ####################################################

# vector field
function TMvf!(dz, z, p, t)
    @unpack J, α, E0, τ, τD, τF, U0 = p
    E, x, u = z
    SS0 = J * u * x * E + E0
    SS1 = α * log(1 + exp(SS0 / α))
    dz[1] = (-E + SS1) / τ
    dz[2] = (1.0 - x) / τD - u * x * E
    dz[3] = (U0 - u) / τF + U0 * (1.0 - u) * E
    dz
end

# out of place method
TMvf(z, p) = TMvf!(similar(z), z, p, 0)

# parameter values
par_tm = (α=1.5, τ=0.013, J=3.07, E0=-2.0, τD=0.200, U0=0.3, τF=1.5, τS=0.007)

# initial condition
z0 = [0.238616, 0.982747, 0.367876]

################################## Branch of equilibria ##############################################

# Bifurcation Problem
prob = BifurcationProblem(TMvf, z0, par_tm, (@lens _.E0);
    recordFromSolution=(x, p) -> (E=x[1], x=x[2], u=x[3]))

# continuation options
opts_br = ContinuationPar(pMin=-10.0, pMax=-0.9,
    # parameters to have a smooth result
    ds=0.04, dsmax=0.05,)

# continuation of equilibria
br = continuation(prob, PALC(tangent=Bordered()), opts_br;
    plot=true, normC=norminf)

scene = plot(br, plotfold=false, markersize=3, legend=:topleft)

################################## Branch of periodic orbits with Trapezoid method ##################

# newton parameters
optn_po = NewtonPar(verbose=true, tol=1e-10, maxIter=10)

# continuation parameters
opts_po_cont = ContinuationPar(opts_br, dsmax=0.1, ds=-0.0001, dsmin=1e-4,
    maxSteps=90, newtonOptions=(@set optn_po.tol = 1e-7), tolStability=1e-8)

# arguments for periodic orbits
args_po = (recordFromSolution=(x, p) -> begin
        xtt = BK.getPeriodicOrbit(p.prob, x, p.p)
        return (max=maximum(xtt[1, :]),
            min=minimum(xtt[1, :]),
            period=getPeriod(p.prob, x, p.p))
    end,
    plotSolution=(x, p; k...) -> begin
        xtt = BK.getPeriodicOrbit(p.prob, x, p.p)
        arg = (marker=:d, markersize=1)
        plot!(xtt.t, xtt[1, :]; label="E", arg..., k...)
        plot!(xtt.t, xtt[2, :]; label="x", arg..., k...)
        plot!(xtt.t, xtt[3, :]; label="u", arg..., k...)
        plot!(br; subplot=1, putspecialptlegend=false)
    end,
    # we use the supremum norm
    normC=norminf)

Mt = 200 # number of time sections
br_potrap = continuation(
    # we want to branch form the 4th bif. point
    br, 4, opts_po_cont,
    # we want to use the Trapeze method to locate PO
    PeriodicOrbitTrapProblem(M=Mt);
    # regular continuation options
    verbosity=2, plot=true,
    args_po...
)

scene = plot(br, br_potrap, markersize=3)
plot!(scene, br_potrap.param, br_potrap.min, label="")

################################## Plot of some of the periodic orbits as function of E0 ###############

plot()
# fetch the saved solutions
for sol in br_potrap.sol[1:2:40]
    # periodic orbit
    po = sol.x
    # get the mesh and trajectory
    traj = BK.getPeriodicOrbit(br_potrap.prob, po, @set par_tm.E0 = sol.p)
    plot!(traj[1, :], traj[2, :], xlabel="E", ylabel="x", label="")
end
title!("")

################################## Branch of periodic orbits with Orthogonal Collocation ###############

# continuation parameters
opts_po_cont = ContinuationPar(opts_br, dsmax=0.15, ds=-0.001, dsmin=1e-4,
    maxSteps=100, newtonOptions=(@set optn_po.tol = 1e-8),
    tolStability=1e-5)

Mt = 30 # number of time sections
br_pocoll = @time continuation(
    # we want to branch form the 4th bif. point
    br, 4, opts_po_cont,
    # we want to use the Collocation method to locate PO, with polynomial degree 4
    PeriodicOrbitOCollProblem(Mt, 4; meshadapt=true);
    # regular continuation options
    verbosity=2, plot=true,
    # we reject the step when the norm norm of the residual is high
    callbackN=BK.cbMaxNorm(100.0),
    args_po...)

Scene = title!("")

################################## Periodic orbits with Parallel Standard Shooting ###################

using DifferentialEquations

# this is the ODEProblem used with `DiffEqBase.solve`
probsh = ODEProblem(TMvf!, copy(z0), (0.0, 1.0), par_tm; abstol=1e-12, reltol=1e-10)

opts_po_cont = ContinuationPar(opts_br, dsmax=0.1, ds=-0.0001, dsmin=1e-4, maxSteps=120, tolStability=1e-4)

br_posh = @time continuation(
    br, 4, opts_po_cont,
    # this is where we tell that we want Standard Shooting
    # with 15 time sections
    ShootingProblem(15, probsh, Rodas5(), parallel=true);
    # this to help branching
    δp=0.0005,
    # deflation helps not converging to an equilibrium instead of a PO
    usedeflation=true,
    # regular continuation parameters
    verbosity=2, plot=true,
    args_po...,
    # we reject the step when the norm norm of the residual is high
    callbackN=BK.cbMaxNorm(10)
)

Scene = title!("")