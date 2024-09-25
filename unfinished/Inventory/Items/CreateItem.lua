local DEFAULT_PROPS = {
    Sellback = 0,
    Weight = 1,
    Cost = 1,
    Droppable = true,
    Description = "",
}

return function(props: typeof(DEFAULT_PROPS))
    local data = table.clone(DEFAULT_PROPS)

    for i,v in props do
        data[i] = v
    end
end