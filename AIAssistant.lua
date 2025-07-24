local component = require("component")
local event = require("event")
local internet = require("internet")
local io = require("io")

local meInterface = component.me_interface
local chatbox = component.chat_box

local json = require("Json")

local chatCache = {}

local assistantName = "Assistant"
local ownerName = "Diamantino_Op"

local debugEnabled = false

local key = ""

local genTools = {
    {
        functionDeclarations = {
            {
                name = "appliedEnergisticsGetStoredItems",
                description = "Request all the stored items in the Applied Energistics network",
                parameters = {
                    type = "object",
                    properties = {
                        test = {
                            type = "string",
                            description = "A test property, can be set to whatever"
                        }
                    },
                    required = {
                        "test"
                    }
                }
            }
        }
    }
}

local context = [[
You are an assistant for a minecraft base in the Gregtech New Horizons modpack in minecraft.
You are connected to multiple peripherals.
Format the output for the minecraft chat.
The owner name is: 
]]

context = context .. ownerName

function appliedEnergisticsGetStoredItems()
    local itemList = {}

    for _, item in ipairs(meInterface.getItemsInNetwork()) do
        table.insert(itemList, {
            name = item.label,
            amount = item.size
        })
    end

    return {
        items = itemList
    }
end

function processCommand(cmd, args)
    chatbox.say("Executing cmd: " .. cmd)

    if cmd == "sendChatMessage" then
        if #args > 0 then
            chatbox.say(args[1])
        else
            chatbox.say("sendChatMessage: Wrong arg amount")
        end
    elseif cmd == "appliedEnergisticsGetStoredItems" then
        return appliedEnergisticsGetStoredItems()
    end
end

function sendAIRequest(payload)
    local geminiHttp = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" .. key

    local jsonData = json.encode({
        system_instruction = {
            parts = {
                {
                    text = context
                }
            }
        },
        contents = payload,
        tools = genTools,
        tool_config = {
            function_calling_config = {
                mode = "auto"
            }
        }
    })

    jsonData:gsub("\"args\": []", "\"args\": {}")

    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json"
    }

    local response = internet.request(geminiHttp, jsonData, headers, "POST")

    if debugEnabled then
        local code, message, _ = getmetatable(response).__index.response()

        chatbox.say("Http Code: " .. tostring(code))
        chatbox.say("Http Message: " .. tostring(message))
    end

    local result = ""
    for chunk in response do result = result .. chunk end

    local responseJson = json.decode(result)

    local parts = {}
    local functionReturns = {}

    if responseJson and responseJson.candidates and #responseJson.candidates > 0 and responseJson.candidates[1].content and #responseJson.candidates[1].content.parts > 0 then
        for _, part in ipairs(responseJson.candidates[1].content.parts) do
            if part.text then
                table.insert(parts, {
                    text = part.text
                })

                chatbox.say(part.text)
            elseif part.functionCall then
                table.insert(parts, {
                    functionCall = part.functionCall
                })

                table.insert(functionReturns, {
                    functionResponse = {
                        name = part.functionCall.name,
                        response = processCommand(part.functionCall.name, part.functionCall.args)
                    }
                })
            end
        end
    end

    table.insert(chatCache, {
        role = "model",
        parts = parts
    })

    updateCacheFile()

    if #functionReturns > 0 then
        sendFunctionResults(functionReturns)
    end
end

function updateCacheFile() 
    local file = io.open("/home/GTNH-AI/Cache.json", "w")

    file:write(json.encode(chatCache))

    file:close()
end

function sendAIMessage(msg)
    table.insert(chatCache, {
        role = "user",
        parts = {
            {
                text = msg
            }
        }
    })

    sendAIRequest(chatCache)
end

function sendFunctionResults(resObj) 
    table.insert(chatCache, {
        role = "user",
        parts = resObj
    })

    sendAIRequest(chatCache)
end

function messageReceived(id, _, sender, content)
    if sender == ownerName and content:sub(1,#assistantName) == assistantName then
        content = content:gsub("Assistant ", "")

        if content == "stop" then
            chatbox.say("Stopping AI Assistant!")

            event.ignore("chat_message", messageReceived)
        else
            sendAIMessage(content)
        end
    end
end

function init()
    local cacheFile = io.open("/home/GTNH-AI/Cache.json", "r")

    if cacheFile then
        chatCache = json.decode(cacheFile:read())
        cacheFile:close()
    else
        chatCache = {}
    end

    local keyFile = io.open("/home/GTNH-AI/Key.txt", "r")

    if keyFile then
        key = keyFile:read()
        keyFile:close()
    else
        chatbox.say("Error: Cannot read key!")
    end
end

chatbox.setName("Diamond Assistant")

init()

event.listen("chat_message", messageReceived)
