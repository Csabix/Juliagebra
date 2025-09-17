const AbstractMortonCodeType = Union{UInt32, UInt64}



"""
```julia
function ExpandBits16by2(a::UInt16)::UInt32
```

Expands 16 bits into 32 by doubling the original bits positions (0 based) and adding 0 in the intermediate slots.

# Arguments
- `a`: the input value

# Returns
- `UInt32`: the expanded value

# Examples
```julia
julia> ExpandBits16by2(0b0000000000001111) # => 0b00000000000000000000000001010101
julia> ExpandBits16by2(0b1111111111111111) # => 0b01010101010101010101010101010101
julia> ExpandBits16by2(0b1010101010101010) # => 0b01000100010001000100010001000100
julia> ExpandBits16by2(0x3033) # => 0x05000505
julia> ExpandBits16by2(0xF00D) # => 0x55000051
julia> ExpandBits16by2(0xBEEF) # => 0x45545455
julia> ExpandBits16by2(0x0123) # => 0x00010405
julia> ExpandBits16by2(0x4567) # => 0x10111415
julia> ExpandBits16by2(0x89AB) # => 0x40414445
julia> ExpandBits16by2(0xCDEF) # => 0x50515455
```

# Notes
- because its 0 based the most significant bit will always be 0
"""
function ExpandBits16by2(a::UInt16)::UInt32
    v::UInt32 = UInt32(a)
    v = (v | (v << 8)) & 0x00FF00FF
    v = (v | (v << 4)) & 0x0F0F0F0F
    v = (v | (v << 2)) & 0x33333333
    v = (v | (v << 1)) & 0x55555555
    return v
end

"""
```julia
function ExpandBits32by2(a::UInt32)::UInt64
```

Expands 32 bits into 64 by doubling the original bits positions (0 based) and adding 0 in the intermediate slots.

# Arguments
- `a`: the input value

# Returns
- `UInt64`: the expanded value

# Examples
```julia
julia> ExpandBits32by2(0b00000000000000000000000000001111) # => 0b0000000000000000000000000000000000000000000000000000000001010101
julia> ExpandBits32by2(0b01000000110000011100001000001111) # => 0b0001000000000000010100000000000101010000000001000000000001010101
julia> ExpandBits32by2(0b11111111111111111111111111111111) # => 0b0101010101010101010101010101010101010101010101010101010101010101
julia> ExpandBits32by2(0xDEADBEEF) # => 0x5154445145545455
julia> ExpandBits32by2(0x01234567) # => 0x0001040510111415
julia> ExpandBits32by2(0x89ABCDEF) # => 0x4041444550515455
```

# Notes
- because its 0 based the most significant bit will always be 0
"""
function ExpandBits32by2(a::UInt32)::UInt64
    v::UInt64 = UInt64(a)
    v = (v | (v << 16)) & 0x0000FFFF0000FFFF
    v = (v | (v <<  8)) & 0x00FF00FF00FF00FF
    v = (v | (v <<  4)) & 0x0F0F0F0F0F0F0F0F
    v = (v | (v <<  2)) & 0x3333333333333333
    v = (v | (v <<  1)) & 0x5555555555555555
    return v
end

"""
```julia
function ExpandBits10By3(a::UInt16)::UInt32
```

Expands 10 bits of a `UIn16` into 30 by tripling the original bits positions (0 based) and adding 0 in the intermediate slots

# Arguments
- `a`: the input value

# Returns
- `UInt32`: the expanded value

# Examples
```julia
julia> ExpandBits10By3(0b0000000000001111) # => 0b00000000000000000000001001001001
julia> ExpandBits10By3(0b0000001111111111) # => 0b00001001001001001001001001001001
julia> ExpandBits10By3(0b1111111111111111) # => 0b00001001001001001001001001001001
julia> ExpandBits10By3(0b0101010101010101) # => 0b00000001000001000001000001000001
julia> ExpandBits10By3(0x0001) # => 0x00000001
julia> ExpandBits10By3(0x0123) # => 0x01008009
julia> ExpandBits10By3(0x0245) # => 0x08040041
julia> ExpandBits10By3(0x0367) # => 0x09048049
julia> ExpandBits10By3(0x0089) # => 0x00200201
julia> ExpandBits10By3(0x01AB) # => 0x01208209
julia> ExpandBits10By3(0x02CD) # => 0x08240241
julia> ExpandBits10By3(0x03EF) # => 0x09248249
```

# Notes
- because its 0 based and only uses 10 bits the 4 most significant bits will always be 0
"""
function ExpandBits10By3(a::UInt16)::UInt32
    v::UInt32 = UInt32(a & 0x03FF)
    v = (v | (v << 16)) & 0xFF0000FF
    v = (v | (v <<  8)) & 0x0F00F00F
    v = (v | (v <<  4)) & 0xC30C30C3
    v = (v | (v <<  2)) & 0x49249249
    return v
end

"""
```julia
function ExpandBits21By3(a::UInt32)::UInt64
```

Expands 21 bits of a `UIn32` into 63 by tripling the original bits positions (0 based) and adding 0 in the intermediate slots

# Arguments
- `a`: the input value

# Returns
- `UInt64`: the expanded value

# Examples
```julia
julia> ExpandBits21By3(0b00000000000000000000000000001111) # => 0b0000000000000000000000000000000000000000000000000000001001001001
julia> ExpandBits21By3(0b00000000000111111111111111111111) # => 0b0001001001001001001001001001001001001001001001001001001001001001
julia> ExpandBits21By3(0b11111111111111111111111111111111) # => 0b0001001001001001001001001001001001001001001001001001001001001001
julia> ExpandBits21By3(0b00000000000100001111000111001101) # => 0b0001000000000000001001001001000000000001001001000000001001000001
julia> ExpandBits21By3(0x00001234) # => 0x0000001008009040
julia> ExpandBits21By3(0x00156789) # => 0x1041048049200201
julia> ExpandBits21By3(0x000ABCDE) # => 0x0208209240241248
julia> ExpandBits21By3(0x001FFFFF) # => 0x1249249249249249
```

# Notes
- because its 0 based and only uses 21 bits the 3 most significant bits will always be 0
"""
function ExpandBits21By3(a::UInt32)::UInt64
    v::UInt64 = UInt64(a & 0x001FFFFF)
    v = (v | (v << 32)) & 0x001F00000000FFFF
    v = (v | (v << 16)) & 0x001F0000FF0000FF
    v = (v | (v <<  8)) & 0x100F00F00F00F00F
    v = (v | (v <<  4)) & 0x10C30C30C30C30C3
    v = (v | (v <<  2)) & 0x1249249249249249
    return v
end

"""
```julia
MortonCode2D32(x::UInt16, y::UInt16)::UInt32
```

Interleaves the bits of 2 16 bit numbers into one 32 bit number, let `a` and `b` represent the bits of the first and second number (`aaaaaaaaaaaaaaaa` and `bbbbbbbbbbbbbbbb`), then the result would be `abababababababababababababababab` 

# Arguments
- `x`: the first number, its bits will be shifted left by 1 before interleaving 
- `y`: the second number, its bits won't be shifted

# Returns
- `UInt32`: the result of the shifting and interleaving

# Examples
```julia
julia> MortonCode2D32(0b1111111111111111, 0b0000000000000000) # => 0b10101010101010101010101010101010
julia> MortonCode2D32(0b0000000000000000, 0b1111111111111111) # => 0b01010101010101010101010101010101
julia> MortonCode2D32(0b1111111111111111, 0b1111111111111111) # => 0b11111111111111111111111111111111
julia> MortonCode2D32(0b1111111100000000, 0b1111000011110000) # => 0b11111111101010100101010100000000
julia> MortonCode2D32(0b0000010100000101, 0b0001000110111011) # => 0b00000001001000110100010101100111
julia> MortonCode2D32(0b1010111110101111, 0b0001000110111011) # => 0b10001001101010111100110111101111
```
"""
function MortonCode2D32(x::UInt16, y::UInt16)::UInt32
    return ((ExpandBits16by2(x) << 1) | ExpandBits16by2(y))
end

"""
```julia
MortonCode2D64(x::UInt32, y::UInt32)::UInt64
```
    
Interleaves the bits of 2 32 bit numbers into one 64 bit number, let `a` and `b` represent the bits of the first and second number (`aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` and `bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`), then the result would be `abababababababababababababababababababababababababababababababab` 

# Arguments
- `x`: the first number, its bits will be shifted left by 1 before interleaving 
- `y`: the second number, its bits won't be shifted

# Returns
- `UInt64`: the result of the shifting and interleaving

# Examples
```julia
julia> MortonCode2D64(0b11111111111111111111111111111111, 0b00000000000000000000000000000000) # => 0b1010101010101010101010101010101010101010101010101010101010101010
julia> MortonCode2D64(0b00000000000000000000000000000000, 0b11111111111111111111111111111111) # => 0b0101010101010101010101010101010101010101010101010101010101010101
julia> MortonCode2D64(0b11111111111111111111111111111111, 0b11111111111111111111111111111111) # => 0b1111111111111111111111111111111111111111111111111111111111111111
julia> MortonCode2D64(0b11111111111111110000000000000000, 0b11111111000000001111111100000000) # => 0b1111111111111111101010101010101001010101010101010000000000000000
julia> MortonCode2D64(0xDEADBEEF, 0xBADC0FFE) # => 0xE7ECD9F28AFDFDFE
julia> MortonCode2D64(0b00000101000001011010111110101111, 0b00010001101110110001000110111011) # => 0x0123456789ABCDEF
```
"""
function MortonCode2D64(x::UInt32, y::UInt32)::UInt64
    return ((ExpandBits32by2(x) << 1) | ExpandBits32by2(y))
end

"""
```julia
MortonCode3D30(x::UInt16, y::UInt16, z::UInt16)::UInt32
```

Interleaves the 10 least significant bits of 3 16 bit numbers into 30 bits of a 32 bit number, let `a` and `b` and `c` represent the bits of the first, second and third number (`iiiiiiaaaaaaaaaa`, `iiiiiibbbbbbbbbb` and `iiiiiicccccccccc` where `i` stand for bits ignored), then the result would be `00abcabcabcabcabcabcabcabcabcabc` (the 2 topmost bits will always be 0) 

# Arguments
- `x`: the first number, its bits (only the 10 least significant) will be shifted left by 2 before interleaving 
- `y`: the second number, its bits (only the 10 least significant) will be shifted left by 1 before interleaving 
- `z`: the third number, its bits (only the 10 least significant) won't be shifted

# Returns
- `UInt32`: the result of the shifting and interleaving

# Examples
```julia
julia> MortonCode3D30(0b1111111111111111, 0b1111111111111111, 0b1111111111111111) # => 0b00111111111111111111111111111111
julia> MortonCode3D30(0b0000001111111111, 0b0000001111111111, 0b0000001111111111) # => 0b00111111111111111111111111111111
julia> MortonCode3D30(0b0000000000000000, 0b0000000000000000, 0b0000001111111111) # => 0b00001001001001001001001001001001
julia> MortonCode3D30(0b0000000000000000, 0b0000001111111111, 0b0000000000000000) # => 0b00010010010010010010010010010010
julia> MortonCode3D30(0b0000000000000000, 0b0000001111111111, 0b0000001111111111) # => 0b00011011011011011011011011011011
julia> MortonCode3D30(0b0000001111111111, 0b0000000000000000, 0b0000000000000000) # => 0b00100100100100100100100100100100
julia> MortonCode3D30(0b0000001111111111, 0b0000000000000000, 0b0000001111111111) # => 0b00101101101101101101101101101101
julia> MortonCode3D30(0b0000001111111111, 0b0000001111111111, 0b0000000000000000) # => 0b00110110110110110110110110110110
julia> MortonCode3D30(0b0000000000110111, 0b0000000000101001, 0b0000000110000101) # => 0x01234567
julia> MortonCode3D30(0b0010010001, 0b0101110000, 0b1111110011) # => 0xBADF00D
```
"""
function MortonCode3D30(x::UInt16, y::UInt16, z::UInt16)::UInt32
    return ((ExpandBits10By3(x) << 2) | (ExpandBits10By3(y) << 1) | ExpandBits10By3(z))
end

"""
```julia
MortonCode3D63(x::UInt32, y::UInt32, z::UInt32)::UInt64
```

Interleaves the 21 least significant bits of 3 32 bit numbers into 63 bits of a 64 bit number, let `a` and `b` and `c` represent the bits of the first, second and third number (`iiiiiiiiiiiaaaaaaaaaaaaaaaaaaaaa`, `iiiiiiiiiiibbbbbbbbbbbbbbbbbbbbb` and `iiiiiiiiiiiccccccccccccccccccccc` where `i` stand for bits ignored), then the result would be `0abcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabc` (the topmost bits will always be 0) 

# Arguments
- `x`: the first number, its bits (only the 21 least significant) will be shifted left by 2 before interleaving 
- `y`: the second number, its bits (only the 21 least significant) will be shifted left by 1 before interleaving 
- `z`: the third number, its bits (only the 21 least significant) won't be shifted

# Returns
- `UInt64`: the result of the shifting and interleaving

# Examples
```julia
julia> MortonCode3D63(0b11111111111111111111111111111111, 0b11111111111111111111111111111111, 0b11111111111111111111111111111111) # => 0b0111111111111111111111111111111111111111111111111111111111111111
julia> MortonCode3D63(0b00000000000111111111111111111111, 0b00000000000111111111111111111111, 0b00000000000111111111111111111111) # => 0b0111111111111111111111111111111111111111111111111111111111111111
julia> MortonCode3D63(0b00000000000000000000000000000000, 0b00000000000000000000000000000000, 0b00000000000111111111111111111111) # => 0b0001001001001001001001001001001001001001001001001001001001001001
julia> MortonCode3D63(0b00000000000000000000000000000000, 0b00000000000111111111111111111111, 0b00000000000000000000000000000000) # => 0b0010010010010010010010010010010010010010010010010010010010010010
julia> MortonCode3D63(0b00000000000000000000000000000000, 0b00000000000111111111111111111111, 0b00000000000111111111111111111111) # => 0b0011011011011011011011011011011011011011011011011011011011011011
julia> MortonCode3D63(0b00000000000111111111111111111111, 0b00000000000000000000000000000000, 0b00000000000000000000000000000000) # => 0b0100100100100100100100100100100100100100100100100100100100100100
julia> MortonCode3D63(0b00000000000111111111111111111111, 0b00000000000000000000000000000000, 0b00000000000111111111111111111111) # => 0b0101101101101101101101101101101101101101101101101101101101101101
julia> MortonCode3D63(0b00000000000111111111111111111111, 0b00000000000111111111111111111111, 0b00000000000000000000000000000000) # => 0b0110110110110110110110110110110110110110110110110110110110110110
julia> MortonCode3D63(0b00000000000001100001010010111111, 0b00000000000000011011110001101101, 0b00000000000000010100101110100111) # => 0x0123456789ABCDEF
```
"""
function MortonCode3D63(x::UInt32, y::UInt32, z::UInt32)::UInt64
    return ((ExpandBits21By3(x) << 2) | (ExpandBits21By3(y) << 1) | ExpandBits21By3(z))
end
