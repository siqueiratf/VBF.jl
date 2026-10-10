# Test-only independent oracle for serialized graph certificates. This uses
# packed integer XOR and binary elimination, without VBF map application or
# ccz_equivalent_function, and can audit saved evidence without rerunning it.
function bgp_test_certificate(record; relation=Symbol(record["relation"]))
    n = record["dimension"]
    n isa Integer && 1 <= n <= 16 || return false
    width = 2n
    columns = record["linear_columns"]
    length(columns) == width || return false
    bound = UInt64(1) << width
    all(v -> v isa Integer && 0 <= v < bound, columns) || return false
    constant = record["constant"]
    constant isa Integer && 0 <= constant < bound || return false
    columns = UInt64.(columns)
    pivots = zeros(UInt64, width)
    rank = 0
    for column in columns
        value = column
        while value != 0
            pivot = 64 - leading_zeros(value)
            if pivots[pivot] == 0
                pivots[pivot] = value
                rank += 1
                break
            end
            value ⊻= pivots[pivot]
        end
    end
    rank == width || return false
    if relation === :ea
        all(column -> column >> n == 0, columns[1:n]) || return false
    elseif relation !== :ccz
        return false
    end
    source, target = record["source_lut"], record["target_lut"]
    length(source) == length(target) == 1 << n || return false
    all(v -> v isa Integer && 0 <= v < 1 << n, source) || return false
    all(v -> v isa Integer && 0 <= v < 1 << n, target) || return false
    image = UInt64[]
    for x in 0:((1 << n)-1)
        point = (UInt64(x) << n) | UInt64(source[x+1])
        value = UInt64(constant)
        while point != 0
            bit = trailing_zeros(point)
            value ⊻= columns[bit+1]
            point &= point - 1
        end
        push!(image, value)
    end
    target_graph = UInt64[(UInt64(x) << n) | UInt64(target[x+1])
        for x in 0:((1 << n)-1)]
    return sort(image) == sort(target_graph)
end
