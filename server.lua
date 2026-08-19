local function getServer()
    if not requestFunction then
        LOG("Executor HTTP request function unavailable.")
        return nil
    end

    local cursor = nil

    for page = 1, 10 do
        local url =
            "https://games.roblox.com/v1/games/"
            .. tostring(PLACE_ID)
            .. "/servers/Public?sortOrder=Asc&limit=100"

        if cursor then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local success, response = pcall(function()
            return requestFunction({
                Url = url,
                Method = "GET"
            })
        end)

        if not success or not response then
            LOG("Server API request failed.")
            return nil
        end

        local body = response.Body or response.body

        if not body then
            LOG("Server API returned no body.")
            return nil
        end

        local decoded

        local decodeSuccess = pcall(function()
            decoded = HttpService:JSONDecode(body)
        end)

        if not decodeSuccess or not decoded then
            LOG("Unable to decode server list.")
            return nil
        end

        for _, server in ipairs(decoded.data or {}) do
            local players = tonumber(server.playing or 0)

            -- STRICTLY TARGET 1-PLAYER SERVERS
            if server.id
                and server.id ~= CURRENT_JOB
                and not visited[server.id]
                and players == 1
                and players < tonumber(server.maxPlayers or 0)
            then
                visited[server.id] = true

                LOG("Found 1-player server: " .. server.id)

                return server.id
            end
        end

        cursor = decoded.nextPageCursor

        if not cursor then
            break
        end
    end

    LOG("No 1-player server found.")
    return nil
end
