
"""
`JuLIP.FIO` : provides some basis file IO. All sub-modules and derived
packages should use these interface functions so that the file formats
can be changed later. This submodule provides

- load_dict
- save_dict
- decode_dict
"""
module FIO

using JSON
using SparseArrays: SparseMatrixCSC


export load_dict, save_dict, save_json, load_json,
       decode_dict, read_dict, write_dict

#######################################################################
#                     Conversions to and from Dict
#######################################################################

# eventually we want to be able to serialise all JuLIP types to Dict
# and back and those Dicts may only contain elementary data types
# this will then allow us to load them back via decode_dict without
# having to know the type in the code

"""
`decode_dict(D::Dict) -> ?`

Looks for a key `__id__` in `D` whose value is used to dynamically dispatch
the decoding to
```julia
convert(Val(Symbol(D["__id__"])))
```
That is, a user defined type must implement this `convert(::Val, ::Dict)`
utility function. The typical code would be
```julia
module MyModule
    struct MyStructA
        a::Float64
    end
    Dict(A::MyStructA) = Dict( "__id__" -> "MyModule_MyStructA",
                               "a" -> a )
    MyStructA(D::Dict) = A(D["a"])
    Base.convert(::Val{:MyModule_MyStructA})
end
```
The user is responsible for choosing an id that is sufficiently unique.

The purpose of this function is to enable the loading of more complex JSON files
and automatically converting the parsed Dict into the appropriate composite
types. It is intentional that a significant burden is put on the user code
here. This will maximise flexibiliy, e.g., by introducing version numbers,
and being able to read old version in the future.
"""
function decode_dict(D::Dict)
    if !haskey(D, "__id__")
        error("JuLIP.IO.decode_dict: `D` has no key `__id__`")
    end
    return read_dict(Val(Symbol(D["__id__"])), D)
end

read_dict(D::Dict) = decode_dict(D)

read_dict(v::Val, D::Dict) = convert(v, D)


#######################################################################
#                     JSON
#######################################################################

function load_dict(fname::AbstractString)
    return JSON.parsefile(fname)
end

function save_dict(fname::AbstractString, D::Dict; indent=2)
    f = open(fname, "w")
    JSON.print(f, D, indent)
    close(f)
    return nothing
end

save_json = save_dict
load_json = load_dict


## De-serialization of some typical objects

# Datatype
write_dict(T::Type) = Dict("__id__" => "Type", "T" => string(T))
read_dict(::Val{:Type}, D::Dict) = Meta.eval(Meta.parse(D["T"]))

# Matrix

write_dict(A::Matrix{T}) where {T <: Number} =
    Dict("__id__" => "JuLIP_Matrix",
         "T"      => write_dict(T),
         "nrows"  => size(A, 1),
         "ncols"  => size(A, 2),
         "data"   => A[:])

function read_dict(::Val{:JuLIP_Matrix}, D::Dict)
   T = read_dict(Val(:Type), D["T"])
   return reshape(T.(D["data"]), D["nrows"], D["ncols"])
end


# SparseMatrixCSC

write_dict(A::SparseMatrixCSC{TF, TI}) where {TF, TI} =
   Dict("__id__" => "SparseMatrixCSC",
        "TF" => write_dict(TF),
        "TI" => write_dict(TI),
        "colptr" => A.colptr,
        "rowval" => A.rowval,
        "nzval" => A.nzval,
        "m" => m,
        "n" => n )

function read_dict(::Val{:SparseMatrixCSC}, D::Dict)
   TF = read_dict(D["TF"])
   TI = read_dict(D["TI"])
   return SparseMatrixCSC(Int(D["m"]), Int(D["n"]),
                           TI.(D["colptr"]), TI.(D["rowval"]), TF.(D["nzval"]))
end



##
end
