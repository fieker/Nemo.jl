###############################################################################
#
#   ArbTypes.jl : Parent and object types for Arb
#
#   Copyright (C) 2015 Tommy Hofmann
#   Copyright (C) 2015 Fredrik Johansson
#
###############################################################################

export ArbField, arb
export AcbField, acb
export ArbPolyRing, arb_poly
export AcbPolyRing, acb_poly
export ArbMatSpace, arb_mat

arb_check_prec(p::Int) = (p >= 2 && p < (typemax(Int) >> 4)) || throw(ArgumentError("invalid precision"))

################################################################################
#
#  Types and memory management for ArbField
#
################################################################################

const ArbFieldID = ObjectIdDict()

type ArbField <: Field
  prec::Int
  
  function ArbField(p::Int = 256)
    arb_check_prec(p)
    try
      return ArbFieldID[p]::ArbField
    catch
      ArbFieldID[p] = new(p)
      return ArbFieldID[p]::ArbField
    end
  end
end

prec(x::ArbField) = x.prec

# these may be used for shallow operations
type arf_struct
  exp::Int # fmpz
  size::UInt # mp_size_t
  d1::Int # mantissa_struct
  d2::Int
end

type mag_struct
  exp::Int # fmpz
  man::UInt # mp_limb_t
end

type arb_struct
  mid_exp::Int # fmpz
  mid_size::UInt # mp_size_t
  mid_d1::Int # mantissa_struct
  mid_d2::Int
  rad_exp::Int # fmpz
  rad_man::UInt
end

type acb_struct
  real_mid_exp::Int # fmpz
  real_mid_size::UInt # mp_size_t
  real_mid_d1::Int # mantissa_struct
  real_mid_d2::Int
  real_rad_exp::Int # fmpz
  real_rad_man::UInt
  imag_mid_exp::Int # fmpz
  imag_mid_size::UInt # mp_size_t
  imag_mid_d1::Int # mantissa_struct
  imag_mid_d2::Int
  imag_rad_exp::Int # fmpz
  imag_rad_man::UInt
end

type arb <: FieldElem
  mid_exp::Int # fmpz
  mid_size::UInt # mp_size_t
  mid_d1::Int # mantissa_struct
  mid_d2::Int
  rad_exp::Int # fmpz
  rad_man::UInt
  parent::ArbField

  function arb()
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    finalizer(z, _arb_clear_fn)
    return z
  end

  function arb(x::arb, p::Int)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_round, :libarb), Void,
                (Ptr{arb}, Ptr{arb}, Int), &z, &x, p)
    finalizer(z, _arb_clear_fn)
    return z
  end

  function arb(s::AbstractString, p::Int)
    s = bytestring(s)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    err = ccall((:arb_set_str, :libarb), Int32, (Ptr{arb}, Ptr{UInt8}, Int), &z, s, p)
    finalizer(z, _arb_clear_fn)
    err == 0 || error("Invalid real string: $(repr(s))")
    return z
  end

  function arb(x::Int)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_si, :libarb), Void, (Ptr{arb}, Int), &z, x)
    finalizer(z, _arb_clear_fn)
    return z
  end
 
  function arb(i::UInt)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_ui, :libarb), Void, (Ptr{arb}, UInt), &z, i)
    finalizer(z, _arb_clear_fn)
    return z
  end

  function arb(x::fmpz)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_fmpz, :libarb), Void, (Ptr{arb}, Ptr{fmpz}), &z, &x)
    finalizer(z, _arb_clear_fn)
    return z
  end
 
  function arb(x::fmpz, p::Int)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_round_fmpz, :libarb), Void,
                (Ptr{arb}, Ptr{fmpz}, Int), &z, &x, p)
    finalizer(z, _arb_clear_fn)
    return z
  end
 
  function arb(x::fmpq, p::Int)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_fmpq, :libarb), Void,
                (Ptr{arb}, Ptr{fmpq}, Int), &z, &x, p)
    finalizer(z, _arb_clear_fn)
    return z
  end

  function arb(mid::arb, rad::arb)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set, :libarb), Void, (Ptr{arb}, Ptr{arb}), &z, &mid)
    ccall((:arb_add_error, :libarb), Void, (Ptr{arb}, Ptr{arb}), &z, &rad)
    finalizer(z, _arb_clear_fn)
    return z
  end

  function arb(x::Float64)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_d, :libarb), Void, (Ptr{arb}, Float64), &z, x)
    finalizer(z, _arb_clear_fn)
    return z
  end

  function arb(x::Float64, p::Int)
    z = new()
    ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
    ccall((:arb_set_d, :libarb), Void, (Ptr{arb}, Float64), &z, x)
    ccall((:arb_set_round, :libarb), Void, (Ptr{arb}, Ptr{arb}, Int), &z, &z, p)
    finalizer(z, _arb_clear_fn)
    return z
  end

  #function arb(x::arf)
  #  z = new()
  #  ccall((:arb_init, :libarb), Void, (Ptr{arb}, ), &z)
  #  ccall((:arb_set_arf, :libarb), Void, (Ptr{arb}, Ptr{arf}), &z, &x)
  #  finalizer(z, _arb_clear_fn)
  #  return z
  #end
end

function _arb_clear_fn(x::arb)
  ccall((:arb_clear, :libarb), Void, (Ptr{arb}, ), &x)
end

elem_type(x::ArbField) = arb

parent(x::arb) = x.parent

function deepcopy(a::arb)
  b = parent(a)()
  ccall((:arb_set, :libarb), Void, (Ptr{arb}, Ptr{arb}), &b, &a)
  return b
end

################################################################################
#
#  Types and memory management for AcbField
#
################################################################################

const AcbFieldID = ObjectIdDict()

type AcbField <: Field
  prec::Int
  
  function AcbField(p::Int = 256)
    arb_check_prec(p)
    try
      return AcbFieldID[p]::AcbField
    catch
      AcbFieldID[p] = new(p)::AcbField
    end
  end
end

prec(x::AcbField) = x.prec

type acb <: FieldElem
  real_mid_exp::Int     # fmpz
  real_mid_size::UInt # mp_size_t
  real_mid_d1::Int    # mantissa_struct
  real_mid_d2::Int
  real_rad_exp::Int     # fmpz
  real_rad_man::UInt
  imag_mid_exp::Int     # fmpz
  imag_mid_size::UInt # mp_size_t
  imag_mid_d1::Int    # mantissa_struct
  imag_mid_d2::Int
  imag_rad_exp::Int     # fmpz
  imag_rad_man::UInt
  parent::AcbField

  function acb()
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_si, :libarb), Void, (Ptr{acb}, Int), &z, x)
    finalizer(z, _acb_clear_fn)
    return z
  end
  
  function acb(i::UInt)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_ui, :libarb), Void, (Ptr{acb}, UInt), &z, i)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::fmpz)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_fmpz, :libarb), Void, (Ptr{acb}, Ptr{fmpz}), &z, &x)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::arb)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_arb, :libarb), Void, (Ptr{acb}, Ptr{arb}), &z, &x)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::acb, p::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_round, :libarb), Void,
                (Ptr{acb}, Ptr{acb}, Int), &z, &x, p)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::fmpz, p::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_round_fmpz, :libarb), Void,
                (Ptr{acb}, Ptr{fmpz}, Int), &z, &x, p)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::fmpq, p::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_fmpq, :libarb), Void,
                (Ptr{acb}, Ptr{fmpq}, Int), &z, &x, p)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::arb, p::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_round_arb, :libarb), Void,
                (Ptr{acb}, Ptr{arb}, Int), &z, &x, p)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::Int, y::Int, p::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_si_si, :libarb), Void,
                (Ptr{acb}, Int, Int, Int), &z, x, y, p)
    ccall((:acb_set_round, :libarb), Void,
                (Ptr{acb}, Ptr{acb}, Int), &z, &z, p)
    finalizer(z, _acb_clear_fn)
    return z
  end

  function acb(x::arb, y::arb, p::Int)
    z = new()
    ccall((:acb_init, :libarb), Void, (Ptr{acb}, ), &z)
    ccall((:acb_set_arb_arb, :libarb), Void,
                (Ptr{acb}, Ptr{arb}, Ptr{arb}, Int), &z, &x, &y, p)
    ccall((:acb_set_round, :libarb), Void,
                (Ptr{acb}, Ptr{acb}, Int), &z, &z, p)
    finalizer(z, _acb_clear_fn)
    return z
  end
end

function _acb_clear_fn(x::acb)
  ccall((:acb_clear, :libarb), Void, (Ptr{acb}, ), &x)
end

parent(x::acb) = x.parent

function deepcopy(a::acb)
  b = parent(a)()
  ccall((:acb_set, :libarb), Void, (Ptr{acb}, Ptr{acb}), &b, &a)
  return b
end

################################################################################
#
#  Types and memory management for ArbPolyRing
#
################################################################################

const ArbPolyRingID = ObjectIdDict()

type ArbPolyRing <: Ring{Arb}
  base_ring::ArbField
  S::Symbol

  function ArbPolyRing(R::ArbField, S::Symbol)
    try
      return ArbPolyRingID[R, S]::ArbPolyRing
    catch
      ArbPolyRingID[R, S] = new(R,S)
      return ArbPolyRingID[R, S]::ArbPolyRing
    end
  end
end


type arb_poly <: PolyElem{arb}
  coeffs::Ptr{Void}
  length::Int
  alloc::Int
  parent::ArbPolyRing

  function arb_poly()
    z = new()
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    finalizer(z, _arb_poly_clear_fn)
    return z
  end

  function arb_poly(x::arb, p::Int)
    z = new() 
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    ccall((:arb_poly_set_coeff_arb, :libarb), Void,
                (Ptr{arb_poly}, Int, Ptr{arb}), &z, 0, &x)
    finalizer(z, _arb_poly_clear_fn)
    return z
  end

  function arb_poly(x::Array{arb, 1}, p::Int)
    z = new() 
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    for i = 1:length(x)
        ccall((:arb_poly_set_coeff_arb, :libarb), Void,
                (Ptr{arb_poly}, Int, Ptr{arb}), &z, i - 1, &x[i])
    end
    finalizer(z, _arb_poly_clear_fn)
    return z
  end

  function arb_poly(x::arb_poly)
    z = new() 
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    ccall((:arb_poly_set, :libarb), Void, (Ptr{arb_poly}, Ptr{arb_poly}), &z, &x)
    finalizer(z, _arb_poly_clear_fn)
    return z
  end

  function arb_poly(x::arb_poly, p::Int)
    z = new() 
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    ccall((:arb_poly_set_round, :libarb), Void,
                (Ptr{arb_poly}, Ptr{arb_poly}, Int), &z, &x, p)
    finalizer(z, _arb_poly_clear_fn)
    return z
  end

  function arb_poly(x::fmpz_poly, p::Int)
    z = new() 
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    ccall((:arb_poly_set_fmpz_poly, :libarb), Void,
                (Ptr{arb_poly}, Ptr{fmpz_poly}, Int), &z, &x, p)
    finalizer(z, _arb_poly_clear_fn)
    return z
  end

  function arb_poly(x::fmpq_poly, p::Int)
    z = new() 
    ccall((:arb_poly_init, :libarb), Void, (Ptr{arb_poly}, ), &z)
    ccall((:arb_poly_set_fmpq_poly, :libarb), Void,
                (Ptr{arb_poly}, Ptr{fmpq_poly}, Int), &z, &x, p)
    finalizer(z, _arb_poly_clear_fn)
    return z
  end
end

function _arb_poly_clear_fn(x::arb_poly)
  ccall((:arb_poly_clear, :libarb), Void, (Ptr{arb_poly}, ), &x)
end

parent(x::arb_poly) = x.parent

elem_type(x::ArbPolyRing) = arb_poly

var(x::ArbPolyRing) = x.S

prec(x::ArbPolyRing) = prec(x.base_ring)

base_ring(a::ArbPolyRing) = a.base_ring

################################################################################
#
#  Types and memory management for AcbPolyRing
#
################################################################################

const AcbPolyRingID = ObjectIdDict()

type AcbPolyRing <: Ring{Arb}
  base_ring::AcbField
  S::Symbol

  function AcbPolyRing(R::AcbField, S::Symbol)
    try
      return AcbPolyRingID[R, S]::AcbPolyRing
    catch
      AcbPolyRingID[R, S] = new(R,S)
      return AcbPolyRingID[R, S]::AcbPolyRing
    end
  end
end

type acb_poly <: PolyElem{acb}
  coeffs::Ptr{Void}
  length::Int
  alloc::Int
  parent::AcbPolyRing

  function acb_poly()
    z = new()
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::acb, p::Int)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    ccall((:acb_poly_set_coeff_acb, :libarb), Void,
                (Ptr{acb_poly}, Int, Ptr{acb}), &z, 0, &x)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::Array{acb, 1}, p::Int)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    for i = 1:length(x)
        ccall((:acb_poly_set_coeff_acb, :libarb), Void,
                (Ptr{acb_poly}, Int, Ptr{acb}), &z, i - 1, &x[i])
    end
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::acb_poly)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    ccall((:acb_poly_set, :libarb), Void, (Ptr{acb_poly}, Ptr{acb_poly}), &z, &x)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::arb_poly, p::Int)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    ccall((:acb_poly_set_arb_poly, :libarb), Void,
                (Ptr{acb_poly}, Ptr{arb_poly}, Int), &z, &x, p)
    ccall((:acb_poly_set_round, :libarb), Void,
                (Ptr{acb_poly}, Ptr{acb_poly}, Int), &z, &z, p)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::acb_poly, p::Int)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    ccall((:acb_poly_set_round, :libarb), Void,
                (Ptr{acb_poly}, Ptr{acb_poly}, Int), &z, &x, p)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::fmpz_poly, p::Int)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    ccall((:acb_poly_set_fmpz_poly, :libarb), Void,
                (Ptr{acb_poly}, Ptr{fmpz_poly}, Int), &z, &x, p)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end

  function acb_poly(x::fmpq_poly, p::Int)
    z = new() 
    ccall((:acb_poly_init, :libarb), Void, (Ptr{acb_poly}, ), &z)
    ccall((:acb_poly_set_fmpq_poly, :libarb), Void,
                (Ptr{acb_poly}, Ptr{fmpq_poly}, Int), &z, &x, p)
    finalizer(z, _acb_poly_clear_fn)
    return z
  end
end

function _acb_poly_clear_fn(x::acb_poly)
  ccall((:acb_poly_clear, :libarb), Void, (Ptr{acb_poly}, ), &x)
end

parent(x::acb_poly) = x.parent

elem_type(x::AcbPolyRing) = acb_poly

var(x::AcbPolyRing) = x.S

prec(x::AcbPolyRing) = prec(x.base_ring)

base_ring(a::AcbPolyRing) = a.base_ring

################################################################################
#
#  Types and memory management for ArbMatSpace
#
################################################################################

const ArbMatSpaceID = ObjectIdDict()

type ArbMatSpace <: Ring{Arb}
  rows::Int
  cols::Int
  base_ring::ArbField

  function ArbMatSpace(R::ArbField, r::Int, c::Int)
    if haskey(ArbMatSpaceID, (R, r, c))
      return ArbMatSpaceID[(R, r, c)]::ArbMatSpace
    else
      z = new(r, c, R)
      ArbMatSpaceID[(R, r, c)] = z
      return z
    end
  end
end

type arb_mat <: MatElem{arb}
  entries::Ptr{Void}
  r::Int
  c::Int
  rows::Ptr{Void}
  parent::ArbMatSpace

  function arb_mat(r::Int, c::Int)
    z = new()
    ccall((:arb_mat_init, :libarb), Void, (Ptr{arb_mat}, Int, Int), &z, r, c)
    finalizer(z, _arb_mat_clear_fn)
    return z
  end

  function arb_mat(a::fmpz_mat)
    z = new()
    ccall((:arb_mat_init, :libarb), Void,
                (Ptr{arb_mat}, Int, Int), &z, a.r, a.c)
    ccall((:arb_mat_set_fmpz_mat, :libarb), Void,
                (Ptr{arb_mat}, Ptr{fmpz_mat}), &z, &a)
    finalizer(z, _arb_mat_clear_fn)
    return z
  end
  
  function arb_mat(a::fmpz_mat, prec::Int)
    z = new()
    ccall((:arb_mat_init, :libarb), Void,
                (Ptr{arb_mat}, Int, Int), &z, a.r, a.c)
    ccall((:arb_mat_set_round_fmpz_mat, :libarb), Void,
                (Ptr{arb_mat}, Ptr{fmpz_mat}, Int), &z, &a, prec)
    finalizer(z, _arb_mat_clear_fn)
    return z
  end

#  function arb_mat(a::fmpq_mat, prec::Int)
#    z = new()
#    ccall((:arb_mat_init, :libarb), Void,
#                (Ptr{arb_mat}, Int, Int), &z, a.r, a.c)
#    ccall((:arb_mat_set_fmpq_mat, :libarb), Void,
#                (Ptr{arb_mat}, Ptr{fmpq_mat}, Int), &z, &a, prec)
#    finalizer(z, _arb_mat_clear_fn)
#    return z
#  end
end

function _arb_mat_clear_fn(x::arb_mat)
  ccall((:arb_mat_clear, :libarb), Void, (Ptr{arb_mat}, ), &x)
end
