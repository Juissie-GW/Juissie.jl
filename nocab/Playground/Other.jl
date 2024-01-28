module Other
export PrintHello

struct Foo
    bar
    baz

end

struct PrintHello
    x::String
end # struct PrintHello

function print_(ph::PrintHello)
    println("Hello Nocab: " * ph.x)
end

end # module
