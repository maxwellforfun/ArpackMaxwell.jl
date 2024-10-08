# This file is a part of Julia. License is MIT: https://julialang.org/license

using ArpackMaxwell
using Test, LinearAlgebra, SparseArrays, StableRNGs

@testset "eigs" begin
    rng = StableRNG(1235)
    n = 10
    areal  = sprandn(rng, n, n, 0.4)
    breal  = sprandn(rng, n, n, 0.4)
    acmplx = complex.(sprandn(rng, n, n, 0.4), sprandn(rng, n, n, 0.4))
    bcmplx = complex.(sprandn(rng, n, n, 0.4), sprandn(rng, n, n, 0.4))

    testtol = 1e-6

    @testset for elty in (Float64, ComplexF64)
        if elty == ComplexF32 || elty == ComplexF64
            a = acmplx
            b = bcmplx
        else
            a = areal
            b = breal
        end
        a_evs = eigvals(Array(a))
        a     = convert(SparseMatrixCSC{elty}, a)
        asym  = copy(a') + a                  # symmetric indefinite
        apd   = a'*a                    # symmetric positive-definite

        b     = convert(SparseMatrixCSC{elty}, b)
        bsym  = copy(b') + b
        bpd   = b'*b + I

        (d,v) = eigs(a, nev=3)
        @test a*v[:,2] ≈ d[2]*v[:,2]
        @test norm(v) > testtol # eigenvectors cannot be null vectors
        (d,v) = eigs(a, LinearAlgebra.I, nev=3) # test eigs(A, B; kwargs...)
        @test a*v[:,2] ≈ d[2]*v[:,2]
        @test norm(v) > testtol # eigenvectors cannot be null vectors
        @test_logs (:warn, "Use symbols instead of strings for specifying which eigenvalues to compute") eigs(a, which="LM")
        @test_logs (:warn, "Adjusting ncv from 1 to 4") eigs(a, ncv=1, nev=2)
        @test_logs (:warn, "Adjusting nev from $n to $(n - 2)") eigs(a, nev=n)
        # (d,v) = eigs(a, b, nev=3, tol=1e-8) # not handled yet
        # @test a*v[:,2] ≈ d[2]*b*v[:,2] atol=testtol
        # @test norm(v) > testtol # eigenvectors cannot be null vectors
        if elty <: LinearAlgebra.BlasComplex
            sr_ind = argmin(real.(a_evs))
            (d, v) = eigs(a, nev=1, which=:SR)
            @test d[1] ≈ a_evs[sr_ind]
            si_ind = argmin(imag.(a_evs))
            (d, v) = eigs(a, nev=1, which=:SI)
            @test d[1] ≈ a_evs[si_ind]
            lr_ind = argmax(real.(a_evs))
            (d, v) = eigs(a, nev=1, which=:LR)
            @test d[1] ≈ a_evs[lr_ind]
            li_ind = argmax(imag.(a_evs))
            (d, v) = eigs(a, nev=1, which=:LI)
            @test d[1] ≈ a_evs[li_ind]
        end

        (d,v) = eigs(asym, nev=3)
        @test asym*v[:,1] ≈ d[1]*v[:,1]
        @test eigs(asym; nev=1, sigma=d[3])[1][1] ≈ d[3]
        @test norm(v) > testtol # eigenvectors cannot be null vectors

        (d,v) = eigs(apd, nev=3)
        @test apd*v[:,3] ≈ d[3]*v[:,3]
        @test eigs(apd; nev=1, sigma=d[3])[1][1] ≈ d[3]

        (d,v) = eigs(apd, bpd, nev=3, tol=1e-8)
        @test apd*v[:,2] ≈ d[2]*bpd*v[:,2] atol=testtol
        @test norm(v) > testtol # eigenvectors cannot be null vectors

        @testset "(shift-and-)invert mode" begin
            (d,v) = eigs(apd, nev=3, sigma=0)
            @test apd*v[:,3] ≈ d[3]*v[:,3]
            @test norm(v) > testtol # eigenvectors cannot be null vectors

            (d,v) = eigs(apd, bpd, nev=3, sigma=0, tol=1e-8)
            @test apd*v[:,1] ≈ d[1]*bpd*v[:,1] atol=testtol
            @test norm(v) > testtol # eigenvectors cannot be null vectors
        end

        @testset "ArgumentErrors" begin
            @test_throws ArgumentError eigs(rand(rng, elty, 2, 2))
            @test_throws ArgumentError eigs(a, nev=-1)
            @test_throws ArgumentError eigs(a, which=:Z)
            @test_throws ArgumentError eigs(a, which=:BE)
            @test_throws DimensionMismatch eigs(a, v0=zeros(elty,n+2))
            @test_throws ArgumentError eigs(a, v0=zeros(Int,n))
            if elty == Float64
                @test_throws ArgumentError eigs(a + copy(transpose(a)), which=:SI)
                @test_throws ArgumentError eigs(a + copy(transpose(a)), which=:LI)
                @test_throws ArgumentError eigs(a, sigma = rand(rng, ComplexF32))
            end
        end
    end

    @testset "Symmetric generalized with singular B" begin
        rng = StableRNG(127)
        n = 10
        k = 3
        A = randn(rng, n, n); A = A'A
        B = randn(rng, n, k); B = B*B'
        @test sort(eigs(A, B, nev = k, sigma = 1.0, explicittransform=:none)[1]) ≈ sort(eigvals(A, B); by=abs)[1:k]
    end
end

@testset "Problematic example from #6965A" begin
    A6965 = [
        1.0   1.0   1.0   1.0   1.0   1.0   1.0  1.0
        -1.0   2.0   0.0   0.0   0.0   0.0   0.0  1.0
        -1.0   0.0   3.0   0.0   0.0   0.0   0.0  1.0
        -1.0   0.0   0.0   4.0   0.0   0.0   0.0  1.0
        -1.0   0.0   0.0   0.0   5.0   0.0   0.0  1.0
        -1.0   0.0   0.0   0.0   0.0   6.0   0.0  1.0
        -1.0   0.0   0.0   0.0   0.0   0.0   7.0  1.0
        -1.0  -1.0  -1.0  -1.0  -1.0  -1.0  -1.0  8.0
    ]
    d, = eigs(A6965,which=:LM,nev=2,ncv=4,tol=eps(), sigma=0.0)
    @test d[1] ≈ 2.5346936860350002
    @test real(d[2]) ≈ 2.6159972444834976
    @test abs(imag(d[2])) ≈ 1.2917858749046127

    # Requires ARPACK 3.2 or a patched 3.1.5
    #T6965 = [ 0.9  0.05  0.05
    #          0.8  0.1   0.1
    #          0.7  0.1   0.2 ]
    #d,v,nconv = eigs(T6965,nev=1,which=:LM)
    # @test T6965*v ≈ d[1]*v atol=1e-6
end

# Example from Quantum Information Theory
import Base: size

mutable struct CPM{T<:LinearAlgebra.BlasFloat} <: AbstractMatrix{T} # completely positive map
    kraus::Array{T,3} # kraus operator representation
end
size(Phi::CPM) = (size(Phi.kraus,1)^2,size(Phi.kraus,3)^2)
LinearAlgebra.issymmetric(Phi::CPM) = false
LinearAlgebra.ishermitian(Phi::CPM) = false
function LinearAlgebra.mul!(rho2::StridedVector{T},Phi::CPM{T},rho::StridedVector{T}) where {T<:LinearAlgebra.BlasFloat}
    rho = reshape(rho,(size(Phi.kraus,3),size(Phi.kraus,3)))
    rho1 = zeros(T,(size(Phi.kraus,1),size(Phi.kraus,1)))
    for s = 1:size(Phi.kraus,2)
        As = view(Phi.kraus,:,s,:)
        rho1 += As*rho*As'
    end
    return copyto!(rho2,rho1)
end

@testset "Test random isometry" begin
    (Q, R) = qr(randn(100, 50))
    Q = reshape(Array(Q), (50, 2, 50))
    # Construct trace-preserving completely positive map from this
    Phi = CPM(copy(Q))
    (d,v,nconv,numiter,numop,resid) = eigs(Phi, nev=1, which=:LM)
    # Properties: largest eigenvalue should be 1, largest eigenvector, when reshaped as matrix
    # should be a Hermitian positive definite matrix (up to an arbitrary phase)

    @test d[1] ≈ 1. # largest eigenvalue should be 1.
    v = reshape(v, (50, 50)) # reshape to matrix
    v /= tr(v) # factor out arbitrary phase
    @test norm(imag(v)) ≈ 0. # it should be real
    v = real(v)
    # @test norm(v-v')/2 ≈ 0. # it should be Hermitian
    # Since this fails sometimes (numerical precision error),this test is commented out
    v = (v + v')/2
    @test isposdef(v)

    # Repeat with starting vector
    (d2, v2, nconv2, numiter2, numop2, resid2) = eigs(Phi, nev=1, which=:LM, v0=reshape(v, (2500,)))
    v2 = reshape(v2, (50,50))
    v2 /= tr(v2)
    @test numiter2 < numiter
    @test v ≈ v2

    # Adjust the tolerance a bit since matrices with repeated eigenvalues
    # can be very stressful to ARPACK and this may therefore fail with
    # info = 3 if the tolerance is too small
    @test eigs(sparse(1.0I, 50, 50), nev=10, tol = 5e-16)[1] ≈ fill(1., 10) #Issue 4246
end

@testset "real svds" begin
    A = sparse([1, 1, 2, 3, 4], [2, 1, 1, 3, 1], [2.0, -1.0, 6.1, 7.0, 1.5])
    S1 = svds(A, nsv = 2)
    S2 = svd(Array(A))

    ## singular values match:
    @test S1[1].S ≈ S2.S[1:2]
    @testset "singular vectors" begin
        ## 1st left singular vector
        s1_left = sign(S1[1].U[3,1]) * S1[1].U[:,1]
        s2_left = sign(S2.U[3,1]) * S2.U[:,1]
        @test s1_left ≈ s2_left

        ## 1st right singular vector
        s1_right = sign(S1[1].V[3,1]) * S1[1].V[:,1]
        s2_right = sign(S2.V[3,1]) * S2.V[:,1]
        @test s1_right ≈ s2_right
    end
    # Issue number 10329
    # Ensure singular values from svds are in
    # the correct order
    @testset "singular values ordered correctly" begin
        B = sparse(Diagonal([1.0, 2.0, 34.0, 5.0, 6.0]))
        S3 = svds(B, ritzvec=false, nsv=2)
        @test S3[1].S ≈ [34.0, 6.0]
        S4 = svds(B, nsv=2)
        @test S4[1].S ≈ [34.0, 6.0]
    end
    @testset "passing guess for Krylov vectors" begin
        S1 = svds(A, nsv = 2, v0=rand(eltype(A), size(A,2)))
        @test S1[1].S ≈ S2.S[1:2]
    end

    @test_throws ArgumentError svds(A, nsv=0)
    @test_throws ArgumentError svds(A, nsv=20)
    @test_throws DimensionMismatch svds(A, nsv=2, v0=rand(size(A,2) + 1))

    @testset "Orthogonal vectors with repeated singular values $i times. Issue 16608" for i in 2:3
        rng = StableRNG(126) # Fragile to compute repeated values without blocking so we set the seed
        v0  = randn(rng, 20)
        d   = sort(rand(rng, 20), rev = true)
        for j in 2:i
            d[j] = d[1]
        end
        A = qr(randn(rng, 20, 20)).Q*Diagonal(d)*qr(randn(rng, 20, 20)).Q
        @testset "Number of singular values: $j" for j in 2:6
            # Default size of subspace
            F = svds(A, nsv = j, v0 = v0)
            @test F[1].U'F[1].U ≈ Matrix(I, j, j)
            @test F[1].V'F[1].V ≈ Matrix(I, j, j)
            @test F[1].S        ≈ d[1:j]
            for k in 3j:2:5j
                # Custom size of subspace
                F = svds(A, nsv = j, ncv = k, v0 = v0)
                @test F[1].U'F[1].U ≈ Matrix(I, j, j)
                @test F[1].V'F[1].V ≈ Matrix(I, j, j)
                @test F[1].S        ≈ d[1:j]
            end
        end
    end
end

@testset "complex svds" begin
    A = sparse([1, 1, 2, 3, 4], [2, 1, 1, 3, 1], exp.(im*[2.0:2:10;]), 5, 4)
    S1 = svds(A, nsv = 2)
    S2 = svd(Array(A))

    ## singular values match:
    @test S1[1].S ≈ S2.S[1:2]
    @testset "singular vectors" begin
        ## left singular vectors
        s1_left = abs.(S1[1].U[:,1:2])
        s2_left = abs.(S2.U[:,1:2])
        @test s1_left ≈ s2_left

        ## right singular vectors
        s1_right = abs.(S1[1].V[:,1:2])
        s2_right = abs.(S2.V[:,1:2])
        @test s1_right ≈ s2_right
    end
    @testset "passing guess for Krylov vectors" begin
        S1 = svds(A, nsv = 2, v0=rand(eltype(A), size(A,2)))
        @test S1[1].S ≈ S2.S[1:2]
    end

    @test_throws ArgumentError svds(A,nsv=0)
    @test_throws ArgumentError svds(A,nsv=20)
    @test_throws DimensionMismatch svds(A,nsv=2,v0=complex(rand(size(A,2)+1)))
end

@testset "promotion" begin
    eigs(rand(1:10, 10, 10))
    eigs(rand(1:10, 10, 10), rand(1:10, 10, 10) |> t -> t't)
    svds(rand(1:10, 10, 8))
    @test_throws MethodError eigs(big.(rand(1:10, 10, 10)))
    @test_throws MethodError eigs(big.(rand(1:10, 10, 10)), rand(1:10, 10, 10))
    @test_throws MethodError svds(big.(rand(1:10, 10, 8)))
end

struct MyOp{S}
    mat::S
end
Base.size(A::MyOp) = size(A.mat)
Base.size(A::MyOp, i::Integer) = size(A.mat, i)
Base.eltype(A::MyOp) = Float64
Base.:*(A::MyOp, B::AbstractMatrix) = A.mat*B
LinearAlgebra.mul!(y::AbstractVector, A::MyOp, x::AbstractVector) = mul!(y, A.mat, x)
LinearAlgebra.adjoint(A::MyOp) = MyOp(adjoint(A.mat))
@testset "svds for non-AbstractMatrix" begin
    A = MyOp(randn(10, 9))
    @test svds(A, v0 = ones(9))[1].S == svds(A.mat, v0 = ones(9))[1].S
end

@testset "low rank" begin
    rng = StableRNG(123)
    @testset "$T coefficients" for T in [Float64, Complex{Float64}]
        @testset "rank $r" for r in [2, 5, 10]
            m, n = 3*r, 4*r
            nsv = 2*r

            FU = qr(randn(rng, T, m, r))
            U = Matrix(FU.Q)
            S = 0.1 .+ sort(rand(rng, r), rev=true)
            FV = qr(randn(rng, T, n, r))
            V = Matrix(FV.Q)

            A = U*Diagonal(S)*V'
            F = svds(A, nsv=nsv)[1]

            @test F.S[1:r] ≈ S
            if T == Complex{Float64}
                # This test fails since ARPACK does not have an Hermitian solver
                # for the complex case. This problem occurs for U in the "fat"
                # case. In the "tall" case the same may happen for V instead.
                @test_broken F.U'*F.U ≈ Matrix{T}(I, nsv, nsv)
            else
                @test F.U'*F.U ≈ Matrix{T}(I, nsv, nsv)
            end
            @test F.V'*F.V ≈ Matrix{T}(I, nsv, nsv)
        end
    end
end


@testset "Problematic examples from #41" begin
    @test all(Matrix(svds([1. 0.; 0. 0.],nsv=1)[1]) ≈ [1. 0.; 0. 0.] for i in 1:10)
    A = [1. 0. 0.; 0. 0. 0.; 0. 0. 0.]
    U,s,V = svds(A,nsv=2)[1]
    @test U*Diagonal(s)*V' ≈ A atol=1e-7
    @test U'U ≈ I
    @test V'V ≈ I
end

# Problematic example from #118
@testset "issue 118" begin
    ωc = 1.2
    ωa = 0.9
    γ = 0.5
    κ = 1.1

    sz = sparse(ComplexF64[1 0; 0 -1])
    sp = sparse(ComplexF64[0 1; 0 0])
    sm = sparse(collect(sp'))
    ids = one(sz)

    a = sparse(diagm(1 => ComplexF64[sqrt(i) for i=1:10]))
    ida = one(a)

    Ha = kron(ida, 0.5*ωa*sz)
    Hc = kron(ωc*a'*a, ids)
    Hint = sparse(kron(a', sm) + kron(a, sp))
    H = Ha + Hc + Hint

    Ja = kron(ida, sqrt(γ)*sm)
    Jc = kron(sqrt(κ)*a, ids)
    J = sqrt(2) .* [Ja, Jc]
    Jdagger = adjoint.(J)
    rates = 0.5 .* ones(length(J))

    spre(x) = kron(one(x), x)
    spost(x) = kron(permutedims(x), one(x))

    L = spre(-1im*H) + spost(1im*H)
    for i=1:length(J)
        jdagger_j = rates[i]/2*Jdagger[i]*J[i]
        L -= spre(jdagger_j) + spost(jdagger_j)
        L += spre(rates[i]*J[i]) * spost(Jdagger[i])
    end

    for _=1:100
        d, rest = eigs(L, nev=2, which=:LR)
        @test abs(d[1]) < 1e-9
    end
end

# Problematic examples from #85
@testset "maxiter reach not throw err" begin
    a = rand(100, 100)
    a = a + a'
    nev = 5
    try
        e, v = eigs(a, nev = nev, maxiter = 2)
    catch err
        @test isa(err, Arpack.XYAUPD_Exception)
        @test err.info == 1
    end

    e, v = eigs(a, nev = nev, maxiter = 2, check = 2)
    println("An warning 'nev = $nev, but only x found!' is expected here:")
    e, v = eigs(a, nev = nev, maxiter = 2, check = 1)
    e0, v0 = eigs(a, nev = nev)
    n = length(e)
    @test all(e[1:n] .≈ e0[1:n])
    @test abs.(v[:, 1:n]'v0[:, 1:n]) ≈ I

    try
        e, v = svds(a, nsv = 5, maxiter = 2)
    catch err
        @show typeof(err)
        @test isa(err, Arpack.XYAUPD_Exception)
        @test err.info == 1
    end

    r, _ = svds(a, nsv = 5, maxiter = 2, check = 2)
    println("An warning 'nev = $nev, but only x found!' is expected here:")
    r, _ = svds(a, nsv = 5, maxiter = 2, check = 1)
    r0, _ = svds(a, nsv = 5)
    n = length(r.S)
    @test all(r.S[1:n] .≈ r0.S[1:n])
    @test abs.(r.U[:, 1:n]'r0.U[:, 1:n]) ≈ I
    @test abs.(r.V[:, 1:n]'r0.V[:, 1:n]) ≈ I
end


# Regression test for #110.
@testset "correct Krylov vector length check" begin
    m = 4
    n = 8
    a  = sprandn(m,n,0.4)

    @test svds(a, nsv=1, v0 = ones(min(m, n)))[1].S ≈ svds(a', nsv=1, v0 = ones(min(m, n)))[1].S
    @test_throws DimensionMismatch svds(a, nsv=1, v0 = ones(max(m, n)))
    @test_throws DimensionMismatch svds(a', nsv=1, v0 = ones(max(m, n)))
end

@testset "ordering modes" begin
    N = 10
    nev = 4
    M = rand(N,N)

    S = eigvals(M)

    abs_imag = abs ∘ imag # ARPACK returns largest,smallest abs(imaginary) (complex pairs come together)

    @testset "no shift-invert" begin
        for (which, sortby, rev) in [(:LM, abs, true), (:LR, real, true), (:LI, abs_imag, true),
                                     (:SM, abs, false), (:SR, real, false), (:SI, abs_imag, false)]
            d, _ = eigs(M, nev=nev, which=which)
            e = partialsort(S, 1:nev, by=sortby, rev=rev)
            @test sortby.(e) ≈ sortby.(d)
        end
    end

    @testset "shift-invert" begin
        for (which, sortby, rev) in [(:LM, abs, true), (:LR, real, true), (:LI, abs_imag, true),
                                     (:SM, abs, false), (:SR, real, false), (:SI, abs_imag, false)]
            d, _ = eigs(M, nev=nev, which=which, sigma=0.0)
            e = S[partialsortperm(S, 1:nev, by=sortby ∘ inv, rev=rev)]
            @test sortby.(e) ≈ sortby.(d)
        end
    end
end
