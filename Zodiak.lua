if not host:isHost() then return end

-- Подключаем модуль Promise
local Promise_module
for _, file in ipairs(listFiles("", true)) do
    if string.find(file, "Promise") then
        Promise_module = file:gsub("%.lua$", ""):gsub("[/\\]", ".")
        break
    end
end
if not Promise_module then return end
local Promise = require(Promise_module)

-- Настройки
local searchNick = "Temp"
local roleNames = {
    ["1384918844262453318"] = '[{"text":"З!одиа!к","color":"#9b2226"}]',
    ["1392122819290071120"] = '[{"text":"Аркана","color":"#bb3e03"}]',
    ["1386034227321241683"] = '[{"text":"Созвездие","color":"#ca6702"}]',
    ["1384918146053570570"] = '[{"text":"Звезда","color":"#ee9b00"}]'
}

local function getRoleIndex(roleId)
    local index = 1
    for id in pairs(roleNames) do
        if id == roleId then return index end
        index = index + 1
    end
    return math.huge
end

local function wrapRoleWithNick(roleJson, nick)
    local wrapped = {string.format('{"text":"> %s ","color":"#C0C0C0"}', nick)}
    for text, color in roleJson:gmatch('"text":"(.-)".-"color":"(.-)"') do
        table.insert(wrapped, string.format('{"text":"%s","color":"%s"}', text, color))
    end
    table.insert(wrapped, '{"text":" <","color":"#C0C0C0"}')
    return "[" .. table.concat(wrapped, ",") .. "]"
end

local lastRole = wrapRoleWithNick("", searchNick)
local isRequesting = false

function events.mouse_press(button)
    if button == 1 then
        local target = player:getTargetedEntity(3)
        if target and target:isPlayer() then
            searchNick = target:getName()
            lastRole = wrapRoleWithNick("", searchNick)
            pings.Search()
        end
    end
end

function pings.Search()
    if isRequesting then return end
    isRequesting = true

    Promise.await(net.http:request("https://splexxhqfig.splexxhqfig.workers.dev/"):method("GET"):send())
        :thenString(function(response)
            local searchLower = searchNick:lower()
            for userStr in response:gmatch('{(.-)}') do
                local nick = userStr:match('"nick":"(.-)"')
                if nick and nick:lower():find(searchLower, 1, true) then
                    local roles = {}
                    for role in userStr:gmatch('"roles":%s*%[(.-)%]') do
                        for r in role:gmatch('"(%d+)"') do
                            if roleNames[r] then table.insert(roles, r) end
                        end
                    end
                    table.sort(roles, function(a,b) return getRoleIndex(a) < getRoleIndex(b) end)
                    if roles[1] then lastRole = wrapRoleWithNick(roleNames[roles[1]], searchNick) end
                    break
                end
            end
            host:setActionbar(lastRole)
            isRequesting = false
        end)
        :catch(function()
            host:setActionbar(lastRole)
            isRequesting = false
        end)
end
