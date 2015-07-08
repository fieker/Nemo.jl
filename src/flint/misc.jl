import Base.hash
export hash

################################
# fun with fmpz ################
#
# should of course be done in c
################################

function fmpz_is_small(a::fmpz)
  return _fmpz_is_small(a.d)
end

function fmpz_limbs(a::fmpz)
  return fmpz_limbs(a.d)
end

function hash_integer(a::fmpz, h::UInt)  ## cloned from the BigInt function
                                         ## in Base
  return _hash_integer(a.d, h)
end

function hash(a::fmpz, h::UInt)
  return hash_integer(a, h)
end

function _fmpz_is_small(a::Int)
  return (reinterpret(Uint64, a)>>62 !=1)
end

function fmpz_limbs(a::Int)
  if _fmpz_is_small(a)
    return 0
  end
  b = unsafe_load(reinterpret(Ptr{Int32}, reinterpret(Uint64,a)<<2), 2) 
  return b
end

function _hash_integer(a::Int, h::UInt)  ## cloned from the BigInt function
                                         ## in Base
  s = fmpz_limbs(a)
  s == 0 && return Base.hash_integer(a, h)
  p = convert(Ptr{UInt}, unsafe_load(reinterpret(Ptr{Uint64}, reinterpret(Uint64,a)<<2), 2))
  b = unsafe_load(p)
  h = Base.hash_uint(ifelse(s < 0, -b, b) $ h) $ h
  for k = 2:abs(s)
    h = Base.hash_uint(unsafe_load(p, k) $ h) $ h
  end
  return h
end

function hash(a::fmpq, h::UInt)
  return _hash_integer(a.num, _hash_integer(a.den, h))
end


function checkbounds(::Int64, ::Int64); nothing; end;
