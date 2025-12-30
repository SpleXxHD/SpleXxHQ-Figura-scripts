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

--------------------------------------------------
-- Host loader
--------------------------------------------------
local function loadHostOnly(script)
    local content = file:readString(script .. ".lua")
    if content ~= nil then
        local fn = loadstring(content, script)
        return fn()
    end
end

local Promise = loadHostOnly("GithubLoader/Promise")

--------------------------------------------------
-- НАСТРОЙКИ
--------------------------------------------------
local searchNick = "Temp"
local UUID
local isRequesting = false

--------------------------------------------------
-- РОЛИ (ДИНАМИЧЕСКИЕ)
--------------------------------------------------
local roleNames = {}      -- roleId -> json text
local rolePriority = {}  -- roleId -> index

--------------------------------------------------
-- Приоритет ролей
--------------------------------------------------
local function getRoleIndex(roleId)
    return rolePriority[roleId] or math.huge
end

--------------------------------------------------
-- Оборачивание ника + роли
--------------------------------------------------
local function wrapNickAndRole(nick, roleJson)
    return string.format(
        '[{"text":"> %s | ","color":"#C0C0C0"},%s,{"text":" <","color":"#C0C0C0"}]',
        nick,
        roleJson:sub(2, -2)
    )
end

--------------------------------------------------
-- Парсинг JSON ролей
-- Формат:
-- [
--   { "username":"Dyno","roles":["123","456"] }
-- ]
--------------------------------------------------
local function loadRoleNamesFromJson(json)
    roleNames = {}
    rolePriority = {}

    local index = 1

    for block in json:gmatch("{(.-)}") do
        local username = block:match('"username"%s*:%s*"(.-)"')
        local rolesBlock = block:match('"roles"%s*:%s*%[(.-)%]')

        if username and rolesBlock then
            for roleId in rolesBlock:gmatch('"(%d+)"') do
                if not roleNames[roleId] then
                    roleNames[roleId] = string.format(
                        '[{"text":"%s","color":"#ee9b00"}]',
                        username
                    )
                    rolePriority[roleId] = index
                    index = index + 1
                end
            end
        end
    end
end

--------------------------------------------------
-- Загрузка ролей с сервера
--------------------------------------------------
function pings.LoadRoles()
    local url = "https://example.com/roles.json" -- <<< ТВОЙ URL
    local req = net.http:request(url):method("GET")

    Promise.await(req:send())
        :thenString(function(response)
            loadRoleNamesFromJson(response)
        end)
        :catch(function(err)
            print("Ошибка загрузки ролей:", err)
        end)
end

pings.LoadRoles()

--------------------------------------------------
-- КЛИК ПО ИГРОКУ
--------------------------------------------------
function events.mouse_press(button, action, modifier)
    if button == 1 then
        local targeted = player:getTargetedEntity(3)
        if targeted and targeted:isPlayer() then
            searchNick = targeted:getName()
            UUID = targeted:getUUID()
            pings.Search()
        end
    end
end

--------------------------------------------------
-- ПОИСК ПОЛЬЗОВАТЕЛЯ
--------------------------------------------------
function pings.Search()
    if isRequesting then return end
    isRequesting = true

    local url = "https://splexxhqfig.splexxhqfig.workers.dev/"
    local req = net.http:request(url):method("GET")

    Promise.await(req:send())
        :thenString(function(response)
            local users = {}

            for userStr in response:gmatch("{(.-)}") do
                local user = {}
                user.nick = userStr:match('"nick"%s*:%s*"(.-)"')
                user.roles = {}

                for roleBlock in userStr:gmatch('"roles"%s*:%s*%[(.-)%]') do
                    for r in roleBlock:gmatch('"(%d+)"') do
                        table.insert(user.roles, r)
                    end
                end

                table.insert(users, user)
            end

            local found = false
            local searchLower = searchNick:lower()

            for _, user in ipairs(users) do
                if user.nick and user.nick:lower():find(searchLower, 1, true) then
                    found = true

                    local filteredRoles = {}

                    for _, roleId in ipairs(user.roles) do
                        if roleNames[roleId] then
                            table.insert(filteredRoles, roleId)
                        end
                    end

                    table.sort(filteredRoles, function(a, b)
                        return getRoleIndex(a) < getRoleIndex(b)
                    end)

                    if filteredRoles[1] then
                        local json = wrapNickAndRole(
                            searchNick,
                            roleNames[filteredRoles[1]]
                        )
                        host:setActionbar(json)
                    else
                        host:setActionbar(
                            string.format(
                                '[{"text":"> %s | Роль не найдена <","color":"#C0C0C0"}]',
                                searchNick
                            )
                        )
                    end
                    break
                end
            end

            isRequesting = false
        end)
        :catch(function(err)
            isRequesting = false
        end)
end

end
