
"""
time_ns() returned UInt64 to ms in Float64.
"""
ns_to_ms(ns::UInt64)::Float64 = (ns/1_000_000.0)

"""
Float64 ms to time_ns() compatible UInt64 ns.
"""
ms_to_ns(ms::Float64)::UInt64 = round(UInt64,ms * 1_000_000)
