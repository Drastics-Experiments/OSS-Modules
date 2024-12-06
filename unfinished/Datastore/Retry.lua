return function<T...>(
    maxAttempts: number,
    initialWait: number,
    fn: (T...) -> any,
    ...: T...
)

    local result, success
    
    for i, maxAttempts do
        result = {pcall(fn, ...)}

        success = result[1]

        if success == true then
            break
        end

        if i < maxAttempts then
            task.wait(initialWait * (2 ^ (i - 1)))
        end
    end

    table.remove(result, 1)

    return {
        success = success,
        returnedValue = result
    }
end