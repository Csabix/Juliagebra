struct AllocRecord
    bytes::Int
    filepath::String
    line_number::Int
    code::String
end

"""
    find_top_allocations(root_dir::String="."; top_x::Int=10, show_code::Bool=true)

Traverses `root_dir` recursively for `.mem` files and prints the top `top_x` lines 
with the highest memory allocations.
"""
function find_top_allocations(root_dir::String="."; top_x::Int=10, show_code::Bool=true)
    allocations = AllocRecord[]

    for (root, _, files) in walkdir(root_dir)
        for file in files
            if endswith(file, ".mem")
                mem_path = joinpath(root, file)
                
                # Clean path: strip .mem (and process ID if present, e.g., .jl.1234.mem -> .jl)
                source_path = replace(abspath(mem_path), r"\.(\d+\.)?mem$" => "")

                line_num = 0
                for line in eachline(mem_path)
                    line_num += 1
                    
                    # Julia .mem lines start with spaces followed by byte count or '-'
                    m = match(r"^\s*(\d+)\s*(.*)$", line)
                    if m !== nothing
                        bytes = parse(Int, m.captures[1])
                        code = m.captures[2]
                        
                        if bytes > 0
                            push!(allocations, AllocRecord(bytes, source_path, line_num, code))
                        end
                    end
                end
            end
        end
    end

    # Sort descending by byte count
    sort!(allocations, by = x -> x.bytes, rev = true)

    # Grab the top X entries
    top_entries = first(allocations, min(top_x, length(allocations)))

    # Output results
    println("\n=== Top $(length(top_entries)) Memory Allocations ===")
    for rec in top_entries
        println("Allocation: $(rec.bytes)b $(rec.filepath):$(rec.line_number)")
        if show_code && !isempty(strip(rec.code))
            println("    └─ $(strip(rec.code))")
        end
    end

    return top_entries
end

# Command-line interface execution
if !isinteractive()
    target_dir = length(ARGS) >= 1 ? ARGS[1] : "."
    top_x = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10
    find_top_allocations(target_dir; top_x=top_x)
end