local itertools = {}

function itertools.getIter(iterator)
    if type(iterator) == "function" then
        return iterator
    elseif type(iterator) == "table" then
        if iterator.iter then
            return iterator.iter
        else
            return coroutine.wrap(function()
                for _, v in ipairs(iterator) do
                    coroutine.yield(v)
                end
            end)
        end
    else
        error("Invalid iterator type: " .. type(iterator))
    end
end

function itertools.wrapRawIter(iter)
    local out = { iter = iter }

    -- add itertools as metamethods
    local mt = getmetatable(out) or {}
    mt.__index = itertools
    mt.__call = function(_, ...)
        return iter(...)
    end
    setmetatable(out, mt)

    return out
end

function itertools.count(start, step, final)
    start = start or 1
    step = step or 1
    final = final or math.huge
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i = start, final, step do
            coroutine.yield(i)
        end
    end))
end

function itertools.filter(iterator, predicate)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i in itertools.getIter(iterator) do
            if predicate(i) then
                coroutine.yield(i)
            end
        end
    end))
end

function itertools.map(iterator, func)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i in itertools.getIter(iterator) do
            coroutine.yield(func(i))
        end
    end))
end

function itertools.take(iterator, n)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i in itertools.getIter(iterator) do
            if n <= 0 then
                break
            end
            coroutine.yield(i)
            n = n - 1
        end
    end))
end

function itertools.takeWhile(iterator, predicate)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i in itertools.getIter(iterator) do
            if not predicate(i) then
                break
            end
            coroutine.yield(i)
        end
    end))
end

function itertools.zip(...)
    local iterators = { ... }
    for i, iterator in ipairs(iterators) do
        iterators[i] = itertools.getIter(iterator)
    end

    return itertools.wrapRawIter(coroutine.wrap(function()
        while true do
            local values = {}
            for _, iterator in ipairs(iterators) do
                local value = iterator()
                if value == nil then
                    return
                end
                table.insert(values, value)
            end
            coroutine.yield(table.unpack(values))
        end
    end))
end

function itertools.zipWith(func, ...)
    local iterators = { ... }
    for i, iterator in ipairs(iterators) do
        iterators[i] = itertools.getIter(iterator)
    end

    return itertools.wrapRawIter(coroutine.wrap(function()
        while true do
            local values = {}
            for _, iterator in ipairs(iterators) do
                local value = iterator()
                if value == nil then
                    return
                end
                table.insert(values, value)
            end
            coroutine.yield(func(table.unpack(values)))
        end
    end))
end

function itertools.reduce(iterator, func, initial)
    local result = initial
    for i in itertools.getIter(iterator) do
        if result == nil then
            result = i
        else
            result = func(result, i)
        end
    end
end

function itertools.all(iterator, predicate)
    for i in itertools.getIter(iterator) do
        if not predicate(i) then
            return false
        end
    end
    return true
end

function itertools.any(iterator, predicate)
    for i in itertools.getIter(iterator) do
        if predicate(i) then
            return true
        end
    end
    return false
end

function itertools.find(iterator, predicate)
    for i in itertools.getIter(iterator) do
        if predicate(i) then
            return i
        end
    end
    return nil
end

function itertools.collect(iterator)
    local result = {}
    for i in itertools.getIter(iterator) do
        table.insert(result, i)
    end
    return result
end

function itertools.enumerate(iterator)
    return itertools.zip(itertools.count(), iterator)
end

function itertools.chain(...)
    local iterators = { ... }
    for i, iterator in ipairs(iterators) do
        iterators[i] = itertools.getIter(iterator)
    end

    return itertools.wrapRawIter(coroutine.wrap(function()
        for _, iterator in ipairs(iterators) do
            for i in iterator do
                coroutine.yield(i)
            end
        end
    end))
end

function itertools.forEach(iterator, func)
    for i in itertools.getIter(iterator) do
        func(i)
    end
end

function itertools.forEachWithIndex(iterator, func)
    for i, v in itertools.enumerate(iterator) do
        func(i, v)
    end
end

function itertools.parallelForEach(iterator, batchSize, func)

    if type(batchSize) == "function" then
        func = batchSize
        batchSize = 1
    end

    -- uses parallel.waitForAll to run the function on each batch. Batch size is maximum size of the batch, not guaranteed. Iterator is first collected
    local elements = itertools.collect(iterator)

    local batchFns = {}
    for i = 1, #elements, batchSize do
        local batch = {}
        for j = i, math.min(i + batchSize - 1, #elements) do
            table.insert(batch, elements[j])
        end
        local iterOffset = i
        table.insert(batchFns, function()
            for k, v in ipairs(batch) do
                func(v, iterOffset + k - 1)
            end
        end)
    end

    parallel.waitForAll(table.unpack(batchFns))

end

function itertools.indexOf(iterator, value)
    for i, v in itertools.enumerate(iterator) do
        if v == value then
            return i
        end
    end
    return nil
end

function itertools.unwrapped(iterator)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i in itertools.getIter(iterator) do
            coroutine.yield(table.unpack(i))
        end
    end))
end

-- does the opposite of unwrapped
function itertools.wrapped(iterator)
    -- it must manually iterate
    local iter = itertools.getIter(iterator)

    return itertools.wrapRawIter(coroutine.wrap(function()
        while true do
            local values = { iter() }
            -- for i = 1, select("#", ) do
            --     table.insert(values, select(i, iter()))
            -- end
            if #values == 0 then
                return
            end
            coroutine.yield(values)
        end
    end))
end

function itertools.pairs(iterator)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i, v in pairs(iterator) do
            coroutine.yield({ i, v })
        end
    end))
end

function itertools.ipairs(iterator)
    return itertools.wrapRawIter(coroutine.wrap(function()
        for i, v in ipairs(iterator) do
            coroutine.yield({ i, v })
        end
    end))
end

if ({ ... })[1] == "examples" then
    print("Examples:")
    print("count(1, 2, 10):map(x+1)")
    for i in itertools.count(1, 2, 10):map(function(x) return x + 1 end) do
        print(i)
    end

    print("filter({ 1, 2, 3, 4, 5 }, function(i) return i % 2 == 0 end):")
    for i in itertools.filter({ 1, 2, 3, 4, 5 }, function(i) return i % 2 == 0 end) do
        print(i)
    end

    -- example that counts up to 10, then down from 20 in intervals of -2.5
    print("count(0, 10):chain(count(20, -2.5, 10))")
    for i in itertools.count(0, 1, 10):chain(itertools.count(20, -2.5, 10)) do
        print(i)
    end

    -- parallel loop over object
    -- local obj = { a = 4, b = 5, c = 6 }
    -- itertools.pairs(obj):parallelForEach(function(v, k)
    --     print(v[1], v[2])
    -- end)
end

return itertools
