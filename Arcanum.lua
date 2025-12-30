--[[
__  __           _        _               
|  \/  | __ _  __| | ___  | |__  _   _     
| |\/| |/ _` |/ _` |/ _ \ | '_ \| | | |    
| |  | | (_| | (_| |  __/ | |_) | |_| |    
|_|  |_|\__,_|\__,_|\___| |_.__/ \__, |    
 ____        _     __  __      _ |___/___  
/ ___| _ __ | | ___\ \/ /__  _| | | |/ _ \ 
\___ \| '_ \| |/ _ \\  / \ \/ / |_| | | | |
 ___) | |_) | |  __//  \  >  <|  _  | |_| |
|____/| .__/|_|\___/_/\_\/_/\_\_| |_|\__\_|
      |_|                                  

discord: splexxhd
https://github.com/SpleXxHD
]]

if host:isHost() then  

    local function loadHostOnly(script)
        local content = file:readString(script .. ".lua")
        if content ~= nil then
            local fn = loadstring(content, script)
            return fn()
        end
    end

    local Promise = loadHostOnly("GithubLoader/Promise")

    -- НАСТРОЙКИ
    local searchNick = "Temp"
    local UUID
    local isRequesting = false

    -- РОЛИ
    local roleNames = {
        ["1392122819290071120"] = '[{"text":"Аркана","color":"#bb3e03"}]',
        ["1386034227321241683"] = '[{"text":"Созвездие","color":"#ca6702"}]',
        ["1384918146053570570"] = '[{"text":"Звезда","color":"#ee9b00"}]',
    }

    local function getRoleIndex(roleId)
        local index = 1
        for id, _ in pairs(roleNames) do
            if id == roleId then
                return index
            end
            index = index + 1
        end
        return math.huge
    end

    local lastRole = '[{"text":"> ","color":"#C0C0C0"},{"text":"'..searchNick..'","color":"#FFFFFF"},{"text":" <","color":"#C0C0C0"}]'

    -- КЛИК ПО ИГРОКУ
    function events.mouse_press(button, action, modifier)
        if button == 1 then
            local targeted = player:getTargetedEntity(3)
            if targeted and targeted:isPlayer() then
                searchNick = targeted:getName()
                UUID = targeted:getUUID()
                lastRole = ""
                pings.Search()
            end
        end
    end

    -- SPM РОЛИ
    local UUIDandRoles = {}

    function pings.RoleSPm()
        local link = "https://spmroles.maximpixel.dev"

        Promise.await(
            net.http:request(link)
                :method("GET")
                :send(), 1000
        )
        :thenJson(function(data)
            UUIDandRoles = data["players"] or {}
        end)
    end

    pings.RoleSPm()

    -- ПОИСК РОЛЕЙ
    function pings.Search()
        if isRequesting then return end
        isRequesting = true

        local url = "https://splexxhqfig.splexxhqfig.workers.dev/"
        local req = net.http:request(url):method("GET")

        Promise.await(req:send())
        :thenString(function(response)

            local users = {}

            for line in response:gmatch('"([^"]+)"') do
                local nick, rolesStr = line:match("^%s*(.-)%s*=%s*(.*)$")
                if nick then
                    local user = { nick = nick, roles = {} }
                    if rolesStr and rolesStr ~= "no roles" then
                        for roleId in rolesStr:gmatch("(%d+)") do
                            table.insert(user.roles, roleId)
                        end
                    end
                    table.insert(users, user)
                end
            end

            local found = false
            local searchLower = searchNick:lower()

            for _, user in ipairs(users) do
                if user.nick and user.nick:lower():find(searchLower, 1, true) then
                    found = true

                    local filteredRoles = {}
                    for _, roleId in ipairs(user.roles) do
                        if roleNames[tostring(roleId)] then
                            table.insert(filteredRoles, tostring(roleId))
                        end
                    end

                    table.sort(filteredRoles, function(a, b)
                        return getRoleIndex(a) < getRoleIndex(b)
                    end)

                    local highestRole = filteredRoles[1] and roleNames[filteredRoles[1]]

                    if highestRole then
                        lastRole = string.format(
                            '[{"text":"> ","color":"#C0C0C0"},{"text":"%s","color":"#FFFFFF"},{"text":" | ","color":"#C0C0C0"},%s,{"text":" <","color":"#C0C0C0"}]',
                            searchNick,
                            highestRole:sub(2, -2)
                        )
                    else
                        lastRole = string.format(
                            '[{"text":"> ","color":"#C0C0C0"},{"text":"%s","color":"#FFFFFF"},{"text":" | Роль не найдена <","color":"#C0C0C0"}]',
                            searchNick
                        )
                    end

                    host:setActionbar(lastRole)
                    break
                end
            end

            -- FALLBACK SPM
            if not found and UUID and UUIDandRoles[UUID] then
                lastRole = string.format(
                    '[{"text":"> ","color":"#C0C0C0"},{"text":"%s","color":"#FFFFFF"},{"text":" | ","color":"#C0C0C0"},{"text":"%s","color":"#ee9b00"},{"text":" <","color":"#C0C0C0"}]',
                    searchNick,
                    UUIDandRoles[UUID]
                )
                host:setActionbar(lastRole)
            end

            isRequesting = false
        end)
        :catch(function()
            isRequesting = false
        end)
    end
end
