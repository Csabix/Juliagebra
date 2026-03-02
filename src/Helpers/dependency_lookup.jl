function _get_caller(stack_trace_index=2)
    real_idx = 1
    for stack_frame in stacktrace()
        if real_idx == stack_trace_index
            return stack_frame.func
        end

        if stack_frame.func !== :_get_caller
            real_idx += 1
        end
    end
end

function _parse_macro_kw_args(kw_names::Vector{Symbol}, kw_args...)
    out = Dict{Symbol,Any}()
    sizehint!(out, length(kw_args))

    for arg in kw_args
        local k::Symbol, v

        if arg isa Symbol
            k = v = arg
        elseif Meta.isexpr(arg, :(=)) && arg.args[1] isa Symbol
            k = arg.args[1]
            v = arg.args[2]
        elseif Meta.isexpr(arg, :parameters)
            error("The macro $(_get_caller()) does not support keyword arguments passed after the ';' symbol (for now).\n" *
                  "To provide keyword arguments, simply provide key=value pairs like they were regular arguments:\n" *
                  "@macro_name(range(1,100,50), color=(1.0,0.0,0.0)) instead of @macro_name(range(1,100,50); color=(1.0,0.0,0.0))")
        else
            error("Ill-formed expression in keyword argument of macro call to $(_get_caller()):\n$arg")
        end

        if haskey(out, k)
            error("Keyword argument '$k' repeated in macro call to $(_get_caller()).")
        end

        if !(k in kw_names)
            error("Unknown keyword argument to macro call $(_get_caller()): $k")
        end

        out[k] = v
    end

    return out
end

"""
Helper for "fixing" default arguments overriden by macro kw_args.
For example for the macro m(x=2,kw_args...) in the call @m(k=5) the expr k=5 will override x instead of being put in kw_args
"""
function _kw_arg_or_default!(arg, default, kw_args::Tuple)
    if Meta.isexpr(arg, :(=))
        return (default, (kw_args..., arg))
    end

    return (arg, kw_args)
end

# this is only here for potential future ctors, where multiple non-kw arguments have default values. usage:
# macro some_ctor(callback, a=2, b=3, c=4, kw_args...)
#   @_collect_kw_args(kw_args, (a, 2), (b, 3), (c, 4))
#   ...
# end
macro _collect_kw_args(kw_args, arg_defaults...)
    gs_found_kw = gensym(:found_kw)

    result = quote
        $gs_found_kw = false
    end

    for iter in arg_defaults
        @assert (Meta.isexpr(iter, :tuple) && length(iter.args) == 2) "Invalid arg_default passed to @_collect_kw_args, expected format: (arg_name::Symbol, arg_default_value::Any)"
        (arg, default) = iter.args

        push!(result.args, quote
            if $gs_found_kw
                $(esc(kw_args)) = ($(esc(kw_args))..., $(esc(arg)))
            elseif Meta.isexpr($(esc(arg)), :(=))
                $(esc(kw_args)) = ($(esc(kw_args))..., $(esc(arg)))
                $(esc(arg)) = $(esc(default))
                $gs_found_kw = true
            end
        end)
    end

    return result
end

function _validate_callback_expr(callback, arg_count::Integer)
    if !MacroTools.isdef(callback)
        error("Expected function in callback argument to $(_get_caller())")
    end

    callback = MacroTools.longdef(callback)

    # remove fn name
    if Meta.isexpr(callback.args[1], :call)
        popfirst!(callback.args[1].args)
        callback.args[1].head = :tuple
    end

    @assert Meta.isexpr(callback.args[1], :tuple) "Unexpected function definition expression structure in callback passed to $(_get_caller()):\n$callback"

    cb_args = callback.args[1].args
    if length(cb_args) != arg_count
        error("Invalid number of arguments in callback definition passed to $(_get_caller()). Expected $arg_count, got $(length(cb_args)) instead.")
    end

    arg_infos = map(MacroTools.splitarg, cb_args)
    syms = Set{Symbol}()
    sizehint!(syms, length(cb_args))
    for (sym, type, slurp, default) in arg_infos
        if !(sym isa Symbol)
            if Meta.isexpr(sym, :parameters)
                error("Keyword arguments are not allowed in callback definitions (in argument $(sym.args[1]) of $(_get_caller()))")
            else
                error("Unexpected argument type in callback definition passed to $(_get_caller()):\n$sym")
            end
        end

        (sym in syms) && error("Redeclaration of argument '$sym' in callback definition argument list passed to $(_get_caller()).")
        (type != :Any) && error("Explicitly typed arguments are not allowed in callback definitions (in argument $sym::$type of $(_get_caller())).")
        slurp && error("Slurped arguments are not allowed in callback definitions (in argument $sym... of $(_get_caller())).")
        !isnothing(default) && error("Default argument values are not allowed in callback definitions (in argument $sym=$default of $(_get_caller())).")

        push!(syms, sym)
    end

    return callback
end

"""Extracts symbols being defined/declared in lhs and adds them to current_scope"""
function _process_lhs!(lhs, current_scope::Set{Symbol}, walk_fn)
    if lhs isa Symbol
        # a = <...>
        push!(current_scope, lhs)
    elseif lhs isa Expr
        # a, b = <...> and (a, b) = <...>
        # (; a, b) = <...> (named destructuring)
        if lhs.head === :tuple || lhs.head === :parameters
            for arg in lhs.args
                _process_lhs!(arg, current_scope, walk_fn)
            end

        # a::T = <...>
        # a, b... = <...>
        # f(x = 2) / f(; x = 2)
        # :(=) is safe-guard for nested kw/named assignment stuff
        elseif lhs.head in (:(::), :(...), :kw, :(=))
            _process_lhs!(lhs.args[1], current_scope, walk_fn)

        # A[i] = <...>
        # obj.prop = <...>
        elseif lhs.head === :ref || lhs.head === :(.)
            walk_fn(lhs, current_scope)
        end
    end
end

"""Sets up inner_scope for use in the traversal of fn body for a fn described by sig"""
function _process_fn_sig!(sig, inner_scope::Set{Symbol}, outer_scope::Set{Symbol}, walk_fn)
    if !(sig isa Expr)
        return
    end

    if sig.head === :where
        for T in @view sig.args[2:end]
            if T isa Symbol
                push!(inner_scope, T)
            elseif Meta.isexpr(T, :(<:)) # supertype-specified type param
                walk_fn(T.args[2], inner_scope)
                if T.args[1] isa Symbol
                    push!(inner_scope, T.args[1])
                end
            end
        end

        sig = sig.args[1]
    end

    if sig.head === :call || sig.head === :tuple
        # only register name for non-lambda fn defs
        if sig.head === :call
            @assert sig.args[1] isa Symbol
            push!(outer_scope, sig.args[1])
        end

        start = sig.head === :call ? 2 : 1
        for arg in @view sig.args[start:end]
            if Meta.isexpr(arg, [:kw, :(=)])
                # uses inner scope to follow default argument sequential binding rules
                walk_fn(arg.args[2], inner_scope)
                _process_lhs!(arg.args[1], inner_scope, walk_fn)
            else
                _process_lhs!(arg, inner_scope, walk_fn)
            end
        end
    end
end

"""
Extracts and returns a set of symbols corresponding to the free variables of the function definition `def::Expr`.

Free variable symbols are referenced symbols inside `def` that cannot be resolved to a declared/defined symbol inside the function and will (presumably) be captured from the defining scope.
"""
function _collect_free_vars(def::Expr, mod::Module)
    # TODO: unit tests
    def = macroexpand(mod, def)

    free_vars = Set{Symbol}()

    function walk!(ex, current_scope::Set{Symbol})
        if ex isa Symbol
            if ex !== :(:) && !(ex in current_scope)
                push!(free_vars, ex)
            end
        elseif ex isa Expr
            head_str = String(ex.head)

            # assignment (single, multi and function shortdef)
            if ex.head === :(=)
                # inline function definitions
                if Meta.isexpr(ex.args[1], [:call, :where])
                    inner_scope = copy(current_scope)
                    _process_fn_sig!(ex.args[1], inner_scope, current_scope, walk!)
                    walk!(ex.args[2], inner_scope)

                # actual assignments
                else
                    walk!(ex.args[2], current_scope)
                    _process_lhs!(ex.args[1], current_scope, walk!)
                end

            # update assignments
            elseif length(head_str) >= 2 && head_str[end] === '='
                walk!(ex.args[2], current_scope)
                walk!(ex.args[1], current_scope)

            # omit called fn symbols
            elseif ex.head === :call
                for arg in @view ex.args[2:end]
                    walk!(arg, current_scope)
                end

            elseif ex.head === :local || ex.head === :const
                for arg in ex.args
                    if Meta.isexpr(arg, :(=))
                        walk!(arg.args[2], current_scope)
                        _process_lhs!(arg.args[1], current_scope, walk!)
                    else
                        _process_lhs!(arg, current_scope, walk!)
                    end
                end

            elseif ex.head === :global
                for arg in ex.args
                    if arg isa Symbol
                        push!(free_vars, arg)
                    elseif Meta.isexpr(arg, :(=))
                        walk!(arg.args[2], current_scope) # walk rhs in current scope
                        walk!(arg.args[1], Set{Symbol}()) # hacky, but this way every used symbol is marked as free
                    else
                        walk!(arg, Set{Symbol}())
                    end
                end

            elseif ex.head === :for
                inner_scope = copy(current_scope)

                iters = Meta.isexpr(ex.args[1], :block) ? ex.args[1].args : [ex.args[1]]
                for iter in iters
                    if Meta.isexpr(iter, :(=))
                        walk!(iter.args[2], inner_scope)
                        _process_lhs!(iter.args[1], inner_scope, walk!)
                    end
                end

                walk!(ex.args[2], inner_scope)

            elseif ex.head === :while
                inner_scope = copy(current_scope)
                walk!(ex.args[1], inner_scope)
                walk!(ex.args[2], inner_scope)

            # let blocks (bindings processed sequentially)
            elseif ex.head === :let
                inner_scope = copy(current_scope)

                bindings = Meta.isexpr(ex.args[1], :block) ? ex.args[1].args : [ex.args[1]]
                for binding in bindings
                    if Meta.isexpr(binding, :(=))
                        walk!(binding, inner_scope)
                    else
                        _process_lhs!(binding, inner_scope, walk!)
                    end
                end

                walk!(ex.args[2], inner_scope)

            # lambdas and fn definitions
            elseif ex.head === :(->) || ex.head === :function
                inner_scope = copy(current_scope)
                _process_fn_sig!(ex.args[1], inner_scope, current_scope, walk!)
                walk!(ex.args[2], inner_scope)

            # fn.(a, b)
            # obj.prop
            elseif ex.head === :(.)
                # walk name of fn/obj being accessed
                walk!(ex.args[1], current_scope)

                # fn-specific case, walk arguments
                if Meta.isexpr(ex.args[2], :tuple)
                    walk!(ex.args[2], current_scope)
                end

            # tuple of values, used widely in the AST structure
            elseif ex.head === :tuple
                for arg in ex.args
                    # named tuple args (kv pairs, we ignore keys)
                    if Meta.isexpr(arg, :(=))
                        walk!(arg.args[2], current_scope)

                    # regular value-only tuples
                    else
                        walk!(arg, current_scope)
                    end
                end

            # comprehensions
            elseif ex.head === :generator
                inner_scope = copy(current_scope)
                for arg in @view ex.args[2:end]
                    # arg is an iterator
                    if Meta.isexpr(arg, :(=))
                        walk!(arg.args[2], inner_scope)
                        _process_lhs!(arg.args[1], inner_scope, walk!)

                    # arg is a condition + iterator(s)
                    elseif Meta.isexpr(arg, :filter)
                        # iterators
                        for iter in @view arg.args[2:end]
                            @assert Meta.isexpr(iter, :(=))
                            walk!(iter.args[2], inner_scope)
                            _process_lhs!(iter.args[1], inner_scope, walk!)
                        end

                        # condition expr
                        walk!(arg.args[1], inner_scope)
                    end
                end

                # projection expr
                walk!(ex.args[1], inner_scope)

            # try/catch/finally
            elseif ex.head === :try
                @assert length(ex.args) >= 3 "Try/catch without a catch block"

                # walk try body
                try_scope = copy(current_scope)
                walk!(ex.args[1], try_scope)

                # walk catch body
                catch_scope = copy(current_scope)
                if ex.args[2] isa Symbol
                    push!(catch_scope, ex.args[2]) # optional error arg
                end
                walk!(ex.args[3], catch_scope)

                # walk (optional) finally body
                if length(ex.args) > 3
                    finally_scope = copy(current_scope)
                    walk!(ex.args[4], finally_scope)
                end

            # generic :kw case
            elseif ex.head === :kw
                walk!(ex.args[2], current_scope)

            # default case, walk all children
            else
                for arg in ex.args
                    walk!(arg, current_scope)
                end
            end
        end
    end

    @assert MacroTools.isdef(def) "Non-function-definition expression passed to collect_free_var_syms"

    def = MacroTools.longdef(def)

    fn_scope = Set{Symbol}()
    _process_fn_sig!(def.args[1], fn_scope, Set{Symbol}(), walk!)
    walk!(def.args[2], fn_scope)

    return free_vars
end

"""Helper for generating the code returned by macro ctors"""
function _create_ctor_wrapper(callback, mod::Module, base_ctor, get_ctor_args = tuple; ctor_kw_args...)
    free_syms = _collect_free_vars(callback, mod)

    body = callback.args[2]

    gs_captured_deps = gensym(:captured_deps)
    gs_callback_args = gensym(:callback_args)
    gs_callback_wrapper = gensym(:callback_wrapper)

    init_block = Expr(:block)
    inner_let_bindings = Expr(:block)
    for sym in free_syms
        sym_gs = gensym(Symbol(:ctor_arg_, sym))

        push!(init_block.args, quote
            $sym_gs = 0

            if $(esc(:(@isdefined($sym)))) && $(esc(sym)) isa PlanDNA
                push!($gs_captured_deps, $(esc(sym)))
                $sym_gs = length($gs_captured_deps)
            end
        end)

        inner_let_rhs = :($sym_gs > 0 ?
            $gs_callback_args[$sym_gs] :
            ($(esc(:(@isdefined($sym)))) ?
                $(esc(sym)) :
                @warn "Failed to find symbol '" * String($(QuoteNode(sym))) * "' in the defining context of a macro constructor. This could be because of an internal deficiency of the macro system, but it could be a user-side error as well. Execution will continue, as things may work without any problems, especially if the symbol does not refer to a dependent. Use the constructors with explicit dependency lists if experiencing any errors, or incorrect behavior, and please open an issue in the Juliagebra github repo."
            )
        )
        push!(inner_let_bindings.args, Expr(:(=), esc(sym), inner_let_rhs))
    end

    base_ctor_args = [:($arg) for arg in get_ctor_args(gs_callback_wrapper, gs_captured_deps)]
    base_ctor_kw_args = [:($(esc(k)) = $(esc(v))) for (k, v) in ctor_kw_args]
    base_ctor_call = :($base_ctor($(base_ctor_args...); $(base_ctor_kw_args...)))

    base_cb_args = [esc(arg_sym) for arg_sym in callback.args[1].args]

    return quote
        $gs_captured_deps = Vector{PlanDNA}()

        $init_block

        $gs_callback_wrapper = ($(base_cb_args...), $gs_callback_args...) -> begin
            let $(inner_let_bindings.args...);
                $(esc(body))
            end
        end

        $base_ctor_call
    end
end
