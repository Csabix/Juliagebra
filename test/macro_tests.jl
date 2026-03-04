macro _test_identity_macro(x)
    :($(esc(x)))
end

@testset verbose=true "Macro Tests" begin
    import Juliagebra as SUT

    @testset verbose=true "Macro Helpers - Free Variable Detection" begin
        test_expr = :(function(a=begin x=0; free0; 1 end, b=x; kw1=free1)
            a; b
            a:b
            b = @_test_identity_macro(free2)
            c = b

            f1() = 2
            d = f1()
            f2(x::T) where {T<:Real} = x + 1
            e = f2(free3)
            f0()

            function f3()
                free4 + 2
            end
            f3()

            function f4(x::T) where {T<:Real}
                x + 1
            end
            f4(a)

            f5 = f1
            f6 = f2
            f7 = f3
            f8 = f4

            e += free5
            free6 *= 2

            local l1, l2::Int, l3::Int = 2, l4::Int = free7
            global free27, g2::Int
            global g3::Int = 2
            global g4::Int = free8
            const c1 = 2
            const c2 = free9
            const c3::Int = 3
            const c4::Int = free10

            for i in a:b
                a += i + free11
            end

            j = 1
            while j <= 10
                a += j + free12
                j += 1
            end

            let x = a, y = b, z = free13, c
                x, y, c, z, free14
            end

            lambda = (x) -> x + free15
            lambda()
            lambda.([free16, a, 3])

            p = (x => free17)
            p.first
            free18.first

            (a, 2, free19)
            kw_f(; kw1=1, kw2=free20) = kw1 + kw2
            kw_f(; kw1=free21, kw2=a)

            [gen_iter + free23 for gen_iter in free22 if gen_iter > 2 && free24 == a]

            try
                # this is not a free var, just tests separation of try/catch/finally scopes
                free25 = 0

                free26
            catch ex
                println(ex * free25)
            finally
                println(free25)
            end
        end)

        free_syms = SUT._collect_free_vars(test_expr, @__MODULE__)

        @testset verbose=true "all free symbols detected" begin
            [(@test Symbol(:free, i) in free_syms) for i in 0:27]
        end

        @testset verbose=true "no locally bound symbol detected" begin
            for sym in free_syms
                @test startswith(String(sym), "free")
            end
        end

        @testset verbose=true "different function definition forms" begin
            @test SUT._collect_free_vars(:(function() end), @__MODULE__) == Set{Symbol}()
            @test SUT._collect_free_vars(:(function f() end), @__MODULE__) == Set{Symbol}()
            @test SUT._collect_free_vars(:(f() = nothing), @__MODULE__) == Set{Symbol}()
            @test SUT._collect_free_vars(:(() -> ()), @__MODULE__) == Set{Symbol}()
        end

        @testset verbose=true "error path" begin
            @test_throws "Non function definition" SUT._collect_free_vars(:(a + 1), @__MODULE__)
            @test_throws "Non function definition" SUT._collect_free_vars(Expr(:block, :a), @__MODULE__)
        end
    end

    @testset verbose=true "Macro Helpers - Macro Keyword Arg Parsing" begin
        @testset verbose=true "happy paths" begin
            @test SUT._parse_macro_kw_args(Symbol[]) == Dict{Symbol,Any}()
            @test SUT._parse_macro_kw_args([:a, :b, :c]) == Dict{Symbol,Any}()
            @test SUT._parse_macro_kw_args([:a], :(a = 1)) == Dict(:a => 1)
            @test SUT._parse_macro_kw_args([:a, :b, :c, :d], :(a = 0), :(b = 1)) == Dict(:a => 0, :b => 1)

            x = 1
            @test SUT._parse_macro_kw_args([:a], :(a = x)) == Dict(:a => :x)
            @test SUT._parse_macro_kw_args([:a, :b], :(a = x), :(b = a)) == Dict(:a => :x, :b => :a)

            @test SUT._parse_macro_kw_args([:a, :b, :c], :(a = 2), :b) == Dict(:a => 2, :b => :b)
        end

        @testset verbose=true "error paths" begin
            @test_throws "Unknown keyword argument" SUT._parse_macro_kw_args(Symbol[], :(a = 2))
            @test_throws "Unknown keyword argument" SUT._parse_macro_kw_args([:a], :(b = 2))
            @test_throws "Unknown keyword argument" SUT._parse_macro_kw_args([:a, :b], :(b = 2), :(c = 3))
            @test_throws "Ill-formed expression" SUT._parse_macro_kw_args([:a], :(a + 2))
            @test_throws "repeated" SUT._parse_macro_kw_args([:a], :(a = 2), :(a = 3))
        end

        @testset verbose=true "_kw_arg_or_default helper" begin
            @test SUT._kw_arg_or_default(:(z=3), 1, (:(x=0),:(y=2))) == (1, (:(x=0),:(y=2),:(z=3)))
            @test SUT._kw_arg_or_default(:(x=0), 1, ()) == (1, (:(x=0),))
            @test SUT._kw_arg_or_default(:y, 1, (:(x=0),)) == (:y, (:(x=0),))
        end
    end

    @testset verbose=true "Macro Helpers - Callback Validation" begin
        function strip_lines_eq(a::Expr, b::Expr)
            a_idx = b_idx = 1

            while a_idx <= length(a.args) && b_idx <= length(b.args)
                a_arg, b_arg = a.args[a_idx], b.args[b_idx]

                if !(a_arg isa LineNumberNode) && !(b_arg isa LineNumberNode) && !strip_lines_eq(a_arg, b_arg)
                    return false
                end

                a_idx += 1
                while a_idx <= length(a.args) && a.args[a_idx] isa LineNumberNode
                    a_idx += 1
                end

                b_idx += 1
                while b_idx <= length(b.args) && b.args[b_idx] isa LineNumberNode
                    b_idx += 1
                end
            end

            return all(ex -> ex isa LineNumberNode, @view a.args[a_idx:end]) &&
                   all(ex -> ex isa LineNumberNode, @view b.args[b_idx:end])
        end
        strip_lines_eq(a, b) = a == b

        @testset verbose=true "happy paths" begin
            @test strip_lines_eq(SUT._validate_callback_expr(:(() -> 2), 0), :(function() 2 end))
            @test strip_lines_eq(SUT._validate_callback_expr(:((a,b) -> 2), 2), :(function(a,b) 2 end))
            @test strip_lines_eq(SUT._validate_callback_expr(:(f(a,b) = 2), 2), :(function(a,b) 2 end))
            @test strip_lines_eq(SUT._validate_callback_expr(:(function(a,b) 2 end), 2), :(function(a,b) 2 end))
        end

        @testset verbose=true "error paths" begin
            @test_throws "Expected function" SUT._validate_callback_expr(:(a + 2), 0)
            @test_throws "Expected function" SUT._validate_callback_expr(Expr(:block, :a), 0)

            @test_throws "Invalid number of arguments" SUT._validate_callback_expr(:(function() end), 1)
            @test_throws "Invalid number of arguments" SUT._validate_callback_expr(:(function(a) end), 0)
            @test_throws "Invalid number of arguments" SUT._validate_callback_expr(:(function(a,b) end), 0)
            @test_throws "Invalid number of arguments" SUT._validate_callback_expr(:(function(a,b) end), 1)

            @test_throws "Keyword arguments" SUT._validate_callback_expr(:(function(;a) end), 1)

            @test_throws "Redeclaration" SUT._validate_callback_expr(:(function(a,a) end), 2)
            @test_throws "typed arguments" SUT._validate_callback_expr(:(function(a::Int) end), 1)
            @test_throws "Slurped arguments" SUT._validate_callback_expr(:(function(a...) end), 1)
            @test_throws "Slurped arguments" SUT._validate_callback_expr(:(function(a, b...) end), 2)
            @test_throws "Default argument values" SUT._validate_callback_expr(:(function(a = 2) end), 1)
        end
    end
end