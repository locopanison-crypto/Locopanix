-- LOCOPANI Bootstrap
-- O script principal permanece no bucket privado do Supabase.
-- Este arquivo pequeno apenas valida a key, baixa o script e inicia a execução.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local SUPABASE_LOADER_URL =
    "https://hshqmleifwkvzjrefabj.supabase.co/functions/v1/locopani-loader"

local KEY_FILE = "locopani_key.dat"

local env = _G
if type(getgenv) == "function" then
    local ok, executorEnv = pcall(getgenv)
    if ok and type(executorEnv) == "table" then
        env = executorEnv
    end
end

local function getRequestFunction()
    local fn = env.request or env.http_request or request or http_request
    if type(fn) == "function" then
        return fn
    end

    local containers = { env.syn, env.http, env.fluxus, syn, http, fluxus }
    for _, container in ipairs(containers) do
        if type(container) == "table" and type(container.request) == "function" then
            return container.request
        end
    end
    return nil
end

local function saveKey(key)
    local writeFn = env.writefile or writefile
    if type(writeFn) == "function" then
        pcall(writeFn, KEY_FILE, key)
    end
end

local function requestScript(key)
    local requestFn = getRequestFunction()
    if type(requestFn) ~= "function" then
        return false, "Este executor não disponibiliza uma função HTTP compatível."
    end

    local body = HttpService:JSONEncode({
        key_code = key,
        roblox_user_id = tostring(player.UserId),
    })

    local ok, response = pcall(function()
        return requestFn({
            Url = SUPABASE_LOADER_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = body,
        })
    end)

    if not ok or type(response) ~= "table" then
        return false, "Não foi possível contactar o servidor LOCOPANI."
    end

    local statusCode = tonumber(response.StatusCode or response.Status or 0) or 0
    local responseBody = response.Body
    if type(responseBody) ~= "string" then
        return false, "O servidor devolveu uma resposta vazia."
    end

    if statusCode < 200 or statusCode >= 300 then
        local message = "Falha ao validar a key (HTTP " .. tostring(statusCode) .. ")."
        local decoded, data = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        if decoded and type(data) == "table" then
            local errors = {
                INVALID_INPUT = "Os dados enviados são inválidos.",
                INVALID_KEY = "Key inválida.",
                KEY_USED = "Esta key já foi utilizada por outra conta.",
                ALREADY_LINKED = "Esta key já está vinculada a outra conta.",
                EXPIRED_KEY = "Esta key expirou.",
                KEY_REVOKED = "Esta key foi revogada.",
                VALIDATION_ERROR = "Erro ao validar a key no servidor.",
                SCRIPT_NOT_FOUND = "O arquivo LOCOPANI não foi encontrado no Storage.",
                SERVER_CONFIG_ERROR = "A configuração do servidor está incompleta.",
            }
            message = errors[data.error] or ("Acesso recusado: " .. tostring(data.error or message))
        end
        return false, message
    end

    if #responseBody < 1000 then
        return false, "O servidor não retornou o arquivo LOCOPANI esperado."
    end

    return true, responseBody
end

-- Reutiliza a biblioteca Argon que o script principal também utiliza.
local argonUrl = "https://raw.githubusercontent.com/JirkaachS/argon-ui/main/argon-ui.luau"
local argon
local okArgon, argonResult = pcall(function()
    return loadstring(game:HttpGet(argonUrl))()
end)
if not okArgon or type(argonResult) ~= "table" then
    warn("LOCOPANI: não foi possível carregar a interface Argon.")
    return
end
argon = argonResult
env.LOCOPANI_ARGON = argon

local window = argon:CreateWindow({
    Name = "LOCOPANI KEY SYSTEM",
    Subtitle = "CRISTAL ROXO 777",
    Theme = "Amethyst",
    ToggleUIKeybind = Enum.KeyCode.RightShift,
    PlayerList = false,
    KeybindList = false,
    ConfigurationSaving = { Enabled = false },
    GuiName = "LOCOPANIKeyArgonUI",
})

pcall(function() window:SetSize(Vector2.new(620, 430)) end)

local tab = window:CreateTab("Key System", "key-round")
tab:CreateSection("Acesso ao LOCOPANI")

local enteredKey = ""
local busy = false
local statusText

tab:CreateInput({
    Name = "Access key",
    PlaceholderText = "LOCO-XXXX-XXXX",
    CurrentValue = "",
    Callback = function(value)
        enteredKey = tostring(value or "")
    end,
})

tab:CreateButton({
    Name = "PEGAR ID ROBLOX",
    Callback = function()
        local userId = tostring(player.UserId)
        local clipboard = env.setclipboard or env.toclipboard
            or env.set_clipboard or setclipboard or toclipboard
        local copied = type(clipboard) == "function" and pcall(clipboard, userId)
        if statusText and statusText.Set then
            statusText:Set(copied and ("ID do Roblox copiado: " .. userId)
                or ("Seu ID do Roblox: " .. userId .. " (copie manualmente)"))
        end
    end,
})

statusText = tab:CreateParagraph({
    Title = "Status",
    Content = "Digite sua chave de acesso e clique em Validar key.",
})

tab:CreateButton({
    Name = "Validar key",
    Callback = function()
        if busy then return end
        local key = string.upper(string.gsub(enteredKey, "%s+", ""))
        if key == "" then
            statusText:Set("Digite sua chave de acesso.")
            return
        end

        busy = true
        statusText:Set("Validando key e baixando LOCOPANI...")
        task.spawn(function()
            local success, result = requestScript(key)
            if not success then
                statusText:Set(tostring(result))
                busy = false
                return
            end

            saveKey(key)
            statusText:Set("Key confirmada. Iniciando LOCOPANI...")
            task.wait(0.25)

            pcall(function() window:Close() end)
            pcall(function()
                if window.ScreenGui then window.ScreenGui:Destroy() end
            end)
            pcall(function()
                if window.CursorGui then window.CursorGui:Destroy() end
            end)

            local compile, compileError = loadstring(result)
            if type(compile) ~= "function" then
                warn("LOCOPANI: erro ao preparar o script: " .. tostring(compileError))
                return
            end

            local runOk, runError = pcall(compile)
            if not runOk then
                warn("LOCOPANI: erro ao iniciar o script: " .. tostring(runError))
            end
        end)
    end,
})

pcall(function() window:FinishLoading() end)
