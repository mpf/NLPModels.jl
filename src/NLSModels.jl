export AbstractNLSModel, nls_meta, NLSCounters, reset!,
       residual, residual!, jac_residual, jac_structure_residual, jac_structure_residual!,
       jac_coord_residual!, jac_coord_residual, jprod_residual, jprod_residual!,
       jtprod_residual, jtprod_residual!, jac_op_residual, jac_op_residual!,
       hess_residual, hess_structure_residual, hess_structure_residual!,
       hess_coord_residual!, hess_coord_residual, jth_hess_residual,
       hprod_residual, hprod_residual!, hess_op_residual, hess_op_residual!,
       NotImplementedError

abstract type AbstractNLSModel <: AbstractNLPModel end

mutable struct NLSCounters
  counters :: Counters
  neval_residual        :: Int
  neval_jac_residual    :: Int
  neval_jprod_residual  :: Int
  neval_jtprod_residual :: Int
  neval_hess_residual   :: Int
  neval_jhess_residual  :: Int
  neval_hprod_residual  :: Int

  function NLSCounters()
    return new(Counters(), 0, 0, 0, 0, 0, 0, 0)
  end
end

function increment!(nls :: AbstractNLSModel, s :: Symbol)
  if s in fieldnames(NLSCounters)
    setfield!(nls.counters, s, getfield(nls.counters, s) + 1)
  else
    setfield!(nls.counters.counters, s, getfield(nls.counters.counters, s) + 1)
  end
end

function decrement!(nls :: AbstractNLSModel, s :: Symbol)
  if s in fieldnames(NLSCounters)
    setfield!(nls.counters, s, getfield(nls.counters, s) - 1)
  else
    setfield!(nls.counters.counters, s, getfield(nls.counters.counters, s) - 1)
  end
end

function sum_counters(c :: NLSCounters)
  s = sum_counters(c.counters)
  for field in fieldnames(NLSCounters)
    field == :counters && continue
    s += getfield(c, field)
  end
  return s
end
sum_counters(nls :: AbstractNLSModel) = sum_counters(nls.counters)

for counter in fieldnames(NLSCounters)
  counter == :counters && continue
  @eval begin
    """
    $($counter)(nlp)

    Get the number of `$(split("$($counter)", "_")[2])` evaluations.
    """
    $counter(nls :: AbstractNLSModel) = nls.counters.$counter
    export $counter
  end
end

for counter in fieldnames(Counters)
  @eval begin
    $counter(nls :: AbstractNLSModel) = nls.counters.counters.$counter
    export $counter
  end
end

import NLPModels: reset!

function reset!(nls :: AbstractNLSModel)
  reset!(nls.counters)
  return nls
end

function reset!(nls_counters :: NLSCounters)
  for f in fieldnames(NLSCounters)
    f == :counters && continue
    setfield!(nls_counters, f, 0)
  end
  reset!(nls_counters.counters)
  return nls_counters
end

include("nls_meta.jl")

nls_meta(nls :: AbstractNLSModel) = nls.nls_meta

include("autodiff_nlsmodel.jl")
include("lls_model.jl")
include("feasibility_residual.jl")

# min ½‖F(x)‖²

# TODO: Add a regularization ½λ²‖V(x)‖²

"""
    Fx = residual(nls, x)

Computes ``F(x)``, the residual at x.
"""
function residual(nls :: AbstractNLSModel, x :: AbstractVector)
  Fx = zeros(eltype(x), nls_meta(nls).nequ)
  residual!(nls, x, Fx)
end

"""
    Fx = residual!(nls, x, Fx)

Computes ``F(x)``, the residual at x.
"""
function residual!(nls :: AbstractNLSModel, x :: AbstractVector, Fx :: AbstractVector)
  throw(NotImplementedError("residual!"))
end

"""
    Jx = jac_residual(nls, x)

Computes ``J(x)``, the Jacobian of the residual at x.
"""
function jac_residual(nls :: AbstractNLSModel, x :: AbstractVector)
  rows, cols = jac_structure_residual(nls)
  vals = jac_coord_residual(nls, x)
  sparse(rows, cols, vals, nls.nls_meta.nequ, nls.meta.nvar)
end

"""
    (rows,cols) = jac_structure_residual!(nls, rows, cols)

Returns the structure of the constraint's Jacobian in sparse coordinate format in place.
"""
function jac_structure_residual!(nls :: AbstractNLSModel, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer})
  throw(NotImplementedError("jac_structure_residual!"))
end

"""
    (rows,cols) = jac_structure_residual(nls)

Returns the structure of the constraint's Jacobian in sparse coordinate format.
"""
function jac_structure_residual(nls :: AbstractNLSModel)
  rows = Vector{Int}(undef, nls.nls_meta.nnzj)
  cols = Vector{Int}(undef, nls.nls_meta.nnzj)
  jac_structure_residual!(nls, rows, cols)
end

"""
    vals = jac_coord_residual!(nls, x, vals)

Computes the Jacobian of the residual at `x` in sparse coordinate format, rewriting
`vals`. `rows` and `cols` are not rewritten.
"""
function jac_coord_residual!(nls :: AbstractNLSModel, x :: AbstractVector, vals :: AbstractVector)
  throw(NotImplementedError("jac_coord_residual!"))
end

"""
    (rows,cols,vals) = jac_coord_residual(nls, x)

Computes the Jacobian of the residual at `x` in sparse coordinate format.
"""
function jac_coord_residual(nls :: AbstractNLSModel, x :: AbstractVector)
  vals = Vector{eltype(x)}(undef, nls.nls_meta.nnzj)
  jac_coord_residual!(nls, x, vals)
end

"""
    Jv = jprod_residual(nls, x, v)

Computes the product of the Jacobian of the residual at x and a vector, i.e.,  ``J(x)v``.
"""
function jprod_residual(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector)
  Jv = zeros(eltype(x), nls_meta(nls).nequ)
  jprod_residual!(nls, x, v, Jv)
end

"""
    Jv = jprod_residual!(nls, x, v, Jv)

Computes the product of the Jacobian of the residual at x and a vector, i.e.,  ``J(x)v``, storing it in `Jv`.
"""
function jprod_residual!(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector, Jv :: AbstractVector)
  throw(NotImplementedError("jprod_residual!"))
end

"""
    Jv = jprod_residual!(nls, rows, cols, vals, v, Jv)

Computes the product of the Jacobian of the residual given by `(rows, cols, vals)`
and a vector, i.e.,  ``J(x)v``, storing it in `Jv`.
"""
function jprod_residual!(nls :: AbstractNLSModel, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}, vals :: AbstractVector, v :: AbstractVector, Jv :: AbstractVector)
  increment!(nls, :neval_jprod_residual)
  coo_prod!(rows, cols, vals, v, Jv)
end

"""
    Jv = jprod_residual!(nls, x, rows, cols, v, Jv)

Computes the product of the Jacobian of the residual at x and a vector, i.e.,  ``J(x)v``, storing it in `Jv`.
The structure of the Jacobian is given by `(rows, cols)`.
"""
jprod_residual!(nls :: AbstractNLSModel, x :: AbstractVector, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}, v :: AbstractVector, Jv :: AbstractVector) = jprod_residual!(nls, x, v, Jv)

"""
    Jtv = jtprod_residual(nls, x, v)

Computes the product of the transpose of the Jacobian of the residual at x and a vector, i.e.,  ``J(x)^Tv``.
"""
function jtprod_residual(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector)
  Jtv = zeros(eltype(x), nls_meta(nls).nvar)
  jtprod_residual!(nls, x, v, Jtv)
end

"""
    Jtv = jtprod_residual!(nls, x, v, Jtv)

Computes the product of the transpose of the Jacobian of the residual at x and a vector, i.e.,  ``J(x)^Tv``, storing it in `Jtv`.
"""
function jtprod_residual!(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector, Jtv :: AbstractVector)
  throw(NotImplementedError("jtprod_residual!"))
end

"""
    Jtv = jtprod_residual!(nls, rows, cols, vals, v, Jtv)

Computes the product of the transpose of the Jacobian of the residual given by `(rows, cols, vals)`
and a vector, i.e.,  ``J(x)^Tv``, storing it in `Jv`.
"""
function jtprod_residual!(nls :: AbstractNLSModel, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}, vals :: AbstractVector, v :: AbstractVector, Jtv :: AbstractVector)
  increment!(nls, :neval_jtprod_residual)
  coo_prod!(cols, rows, vals, v, Jtv)
end

"""
    Jtv = jtprod_residual!(nls, x, rows, cols, v, Jtv)

Computes the product of the transpose Jacobian of the residual at x and a vector, i.e.,  ``J(x)^Tv``, storing it in `Jv`.
The structure of the Jacobian is given by `(rows, cols)`.
"""
jtprod_residual!(nls :: AbstractNLSModel, x :: AbstractVector, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}, v :: AbstractVector, Jtv :: AbstractVector) = jtprod_residual!(nls, x, v, Jtv)

"""
    Jx = jac_op_residual(nls, x)

Computes ``J(x)``, the Jacobian of the residual at x, in linear operator form.
"""
function jac_op_residual(nls :: AbstractNLSModel, x :: AbstractVector)
  prod = @closure v -> jprod_residual(nls, x, v)
  ctprod = @closure v -> jtprod_residual(nls, x, v)
  return LinearOperator{eltype(x)}(nls_meta(nls).nequ, nls_meta(nls).nvar,
                                   false, false, prod, ctprod, ctprod)
end

"""
    Jx = jac_op_residual!(nls, x, Jv, Jtv)

Computes ``J(x)``, the Jacobian of the residual at x, in linear operator form. The
vectors `Jv` and `Jtv` are used as preallocated storage for the operations.
"""
function jac_op_residual!(nls :: AbstractNLSModel, x :: AbstractVector,
                          Jv :: AbstractVector, Jtv :: AbstractVector)
  prod = @closure v -> jprod_residual!(nls, x, v, Jv)
  ctprod = @closure v -> jtprod_residual!(nls, x, v, Jtv)
  return LinearOperator{eltype(x)}(nls_meta(nls).nequ, nls_meta(nls).nvar,
                                   false, false, prod, ctprod, ctprod)
end

"""
    Jx = jac_op_residual!(nls, rows, cols, vals, Jv, Jtv)

Computes ``J(x)``, the Jacobian of the residual given by `(rows, cols, vals)`, in linear operator form. The
vectors `Jv` and `Jtv` are used as preallocated storage for the operations.
"""
function jac_op_residual!(nls :: AbstractNLSModel, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}, vals :: AbstractVector, Jv :: AbstractVector, Jtv :: AbstractVector)
  prod = @closure v -> jprod_residual!(nls, rows, cols, vals, v, Jv)
  ctprod = @closure v -> jtprod_residual!(nls, rows, cols, vals, v, Jtv)
  return LinearOperator{eltype(vals)}(nls_meta(nls).nequ, nls_meta(nls).nvar,
                                 false, false, prod, ctprod, ctprod)
end

"""
    Jx = jac_op_residual!(nls, x, rows, cols, Jv, Jtv)

Computes ``J(x)``, the Jacobian of the residual at x, in linear operator form. The
vectors `Jv` and `Jtv` are used as preallocated storage for the operations.
The structure of the Jacobian should be given by `(rows, cols)`.
"""
function jac_op_residual!(nls :: AbstractNLSModel, x :: AbstractVector, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}, Jv :: AbstractVector, Jtv :: AbstractVector)
  vals = jac_coord_residual(nls, x)
  decrement!(nls, :neval_jac_residual)
  return jac_op_residual!(nls, rows, cols, vals, Jv, Jtv)
end

"""
    H = hess_residual(nls, x, v)

Computes the linear combination of the Hessians of the residuals at `x` with coefficients
`v`.
"""
function hess_residual(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector)
  rows, cols = hess_structure_residual(nls)
  vals = hess_coord_residual(nls, x, v)
  sparse(rows, cols, vals, nls.meta.nvar, nls.meta.nvar)
end

"""
    (rows,cols) = hess_structure_residual(nls)

Returns the structure of the residual Hessian.
"""
function hess_structure_residual(nls :: AbstractNLSModel)
  rows = Vector{Int}(undef, nls.nls_meta.nnzh)
  cols = Vector{Int}(undef, nls.nls_meta.nnzh)
  hess_structure_residual!(nls, rows, cols)
end

"""
    hess_structure_residual!(nls, rows, cols)

Returns the structure of the residual Hessian in place.
"""
function hess_structure_residual!(nls :: AbstractNLSModel, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer})
  throw(NotImplementedError("hess_structure_residual!"))
end

"""
    vals = hess_coord_residual!(nls, x, v, vals)

Computes the linear combination of the Hessians of the residuals at `x` with coefficients
`v` in sparse coordinate format, rewriting `vals`.
"""
function hess_coord_residual!(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector, vals :: AbstractVector)
  throw(NotImplementedError("hess_coord_residual!"))
end

"""
    vals = hess_coord_residual(nls, x, v)

Computes the linear combination of the Hessians of the residuals at `x` with coefficients
`v` in sparse coordinate format.
"""
function hess_coord_residual(nls :: AbstractNLSModel, x :: AbstractVector, v :: AbstractVector)
  vals = Vector{eltype(x)}(undef, nls.nls_meta.nnzh)
  hess_coord_residual!(nls, x, v, vals)
end

"""
    Hj = jth_hess_residual(nls, x, j)

Computes the Hessian of the j-th residual at x.
"""
function jth_hess_residual(nls :: AbstractNLSModel, x :: AbstractVector, i :: Int)
  throw(NotImplementedError("jth_hess_residual"))
end

"""
    Hiv = hprod_residual(nls, x, i, v)

Computes the product of the Hessian of the i-th residual at x, times the vector v.
"""
function hprod_residual(nls :: AbstractNLSModel, x :: AbstractVector, i :: Int, v :: AbstractVector)
  Hv = zeros(eltype(x), nls_meta(nls).nvar)
  hprod_residual!(nls, x, i, v, Hv)
end

"""
    Hiv = hprod_residual!(nls, x, i, v, Hiv)

Computes the product of the Hessian of the i-th residual at x, times the vector v, and stores it in vector Hiv.
"""
function hprod_residual!(nls :: AbstractNLSModel, x :: AbstractVector, i :: Int, v :: AbstractVector, Hiv :: AbstractVector)
  throw(NotImplementedError("hprod_residual!"))
end

"""
    Hop = hess_op_residual(nls, x, i)

Computes the Hessian of the i-th residual at x, in linear operator form.
"""
function hess_op_residual(nls :: AbstractNLSModel, x :: AbstractVector, i :: Int)
  prod = @closure v -> hprod_residual(nls, x, i, v)
  return LinearOperator{eltype(x)}(nls_meta(nls).nvar, nls_meta(nls).nvar,
                                   true, true, prod, prod, prod)
end

"""
    Hop = hess_op_residual!(nls, x, i, Hiv)

Computes the Hessian of the i-th residual at x, in linear operator form. The vector `Hiv` is used as preallocated storage for the operation.
"""
function hess_op_residual!(nls :: AbstractNLSModel, x :: AbstractVector, i :: Int, Hiv :: AbstractVector)
  prod = @closure v -> hprod_residual!(nls, x, i, v, Hiv)
  return LinearOperator{eltype(x)}(nls_meta(nls).nvar, nls_meta(nls).nvar,
                                   true, true, prod, prod, prod)
end

function obj(nls :: AbstractNLSModel, x :: AbstractVector)
  increment!(nls, :neval_obj)
  Fx = residual(nls, x)
  return dot(Fx, Fx) / 2
end

function grad!(nls :: AbstractNLSModel, x :: AbstractVector, g :: AbstractVector)
  increment!(nls, :neval_grad)
  Fx = residual(nls, x)
  return jtprod_residual!(nls, x, Fx, g)
end

function objgrad!(nls :: AbstractNLSModel, x :: AbstractVector, g :: AbstractVector)
  increment!(nls, :neval_obj)
  increment!(nls, :neval_grad)
  Fx = residual(nls, x)
  jtprod_residual!(nls, x, Fx, g)
  return dot(Fx, Fx) / 2, g
end
