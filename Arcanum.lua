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
|____/| .__/|_|\___/_/\_\/_/\_\_| |_|\__\_\
      |_|                                  

discord: splexxhd
https://github.com/SpleXxHD
]]

if host:isHost() then  
    local function loadHostOnly(script)
    local content = file:readString(script .. ".lua")
        if content ~= nil then
            local fn = loadstring(content, script)
            return fn()  -- returns whatever the script returns
        end
    end

local Promise = loadHostOnly("GithubLoader/Promise")

-- Настройки
local searchNick = "Temp"
local UUID


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

local function wrapRoleWithNick(roleJson, nick)
    local roleTable = {}
    for text, color in roleJson:gmatch('"text":"(.-)".-"color":"(.-)"') do
        table.insert(roleTable, {text=text, color=color})
    end

    local wrapped = {}
    table.insert(wrapped, {text="> "..nick.." ", color="#C0C0C0"})
    for _, item in ipairs(roleTable) do
        table.insert(wrapped, item)
    end
    table.insert(wrapped, {text=" <", color="#C0C0C0"})

    local parts = {}
    for _, item in ipairs(wrapped) do
        table.insert(parts, string.format('{"text":"%s","color":"%s"}', item.text, item.color))
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local lastRole = '[{"text":"> '..searchNick..' <","color":"#C0C0C0"}]'
local isRequesting = false -- флаг, что запрос в процессе

function events.mouse_press(button, action, modifier)
    if button == 1 then
        local targeted = player:getTargetedEntity(3)
        if targeted ~= nil and targeted:isPlayer() then
            pings.Search()
            Role1 = ""
            searchNick = ""
            searchNick = targeted:getName()
            UUID = targeted:getUUID()
            lastRole = ""
        end
    end
end

-- СПм роли --

local Names = client.getTabList().players

local UUIDandRoles

function pings.RoleSPm()
    local link = "https://spmroles.maximpixel.dev"

    local payload = toJson(Names)

    local buffer = data:createBuffer(#payload)
    buffer:writeString(payload)
    buffer:setPosition(0)

    Promise.await(
        net.http:request(link)
            :method("GET")
            :send(), 1000)
        :thenJson(function(data)
            UUIDandRoles = data["players"]
        end)
end

pings.RoleSPm()

function pings.Search()
    if isRequesting then return end
    isRequesting = true

    local url = "https://splexxhqfig.splexxhqfig.workers.dev/"
    local req = net.http:request(url):method("GET")

    Promise.await(req:send())
        :thenString(function(response)
            local users = {}

            -- response = JSON массив строк
            for line in response:gmatch('"([^"]+)"') do
                -- line пример: Nick = 123, 456
                local nick, rolesStr = line:match("^%s*(.-)%s*=%s*(.*)$")

                if nick then
                    local user = {
                        nick = nick,
                        roles = {}
                    }

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

            -- Поиск пользователя
            for _, user in ipairs(users) do
                if user.nick and user.nick:lower():find(searchLower, 1, true) then
                    found = true

                    -- Фильтрация ролей
                    local filteredRoles = {}
                    for _, roleId in ipairs(user.roles) do
                        local roleIdStr = tostring(roleId)
                        if roleNames[roleIdStr] then
                            table.insert(filteredRoles, roleIdStr)
                        end
                    end

                    -- Сортировка по приоритету
                    table.sort(filteredRoles, function(a, b)
                        return getRoleIndex(a) < getRoleIndex(b)
                    end)

                    local highestRole = filteredRoles[1] and roleNames[filteredRoles[1]] or nil

                    if highestRole then
                        -- Объединяем ник и роль через |
                        local roleText = wrapRoleWithNick(highestRole, searchNick)
                        -- wrapRoleWithNick делает ["> Nick <" + role], поэтому надо заменить ">" и "<" на "|"
                        -- более простое решение: формируем вручную
                        local actionbarJson = string.format(
                            '[{"text":"> %s | ","color":"#C0C0C0"},%s]',
                            searchNick,
                            highestRole:sub(2, -2) -- убираем квадратные скобки для вставки JSON
                        )
                        lastRole = actionbarJson
                    else
                        lastRole = string.format(
                            '[{"text":"> %s | Роль не найдена <","color":"#C0C0C0"}]',
                            searchNick
                        )
                    end

                    host:setActionbar(lastRole)
                    break
                end
            end

            -- Пользователь не найден — fallback
            if not found then
                if UUID and UUIDandRoles[UUID] then
                    -- Ник будет серебристым, роль — оранжевым
                    lastRole = string.format(
                        '[{"text":"> %s | ","color":"#C0C0C0"},{"text":"%s","color":"#ee9b00"},{"text":" <","color":"#C0C0C0"}]',
                        searchNick,
                        UUIDandRoles[UUID] or ""
                    )
                    host:setActionbar(lastRole)
                end
            end

            isRequesting = false
        end)
        :catch(function(err)
            isRequesting = false
        end)
end





end
