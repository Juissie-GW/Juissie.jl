module Nocab
# import Other
# import Other
include("Other.jl")

foo = Other.Foo(1, 2)

a = Other.PrintHello("test")
Other.print_(a)

# a::Other.PrintHello("test")
# a.print_()

end