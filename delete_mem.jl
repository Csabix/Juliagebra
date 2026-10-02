"""
    clean_mem_files(root_dir::String=".")

Recursively traverses `root_dir` and deletes every `.mem` file found.
"""
function clean_mem_files(root_dir::String=".")
    deleted_count = 0

    println("Searching for .mem files to delete in: $(abspath(root_dir))\n")

    for (root, _, files) in walkdir(root_dir)
        for file in files
            if endswith(file, ".mem")
                filepath = joinpath(root, file)
                try
                    rm(filepath)
                    deleted_count += 1
                    println("Deleted: $filepath")
                catch e
                    println("Error deleting $filepath:$e")
                end
            end
        end
    end

    println("\nClean finished. Total .mem files removed: $deleted_count")
    return deleted_count
end

# Command-line execution
if !isinteractive()
    target_dir = length(ARGS) >= 1 ? ARGS[1] : "."
    clean_mem_files(target_dir)
end