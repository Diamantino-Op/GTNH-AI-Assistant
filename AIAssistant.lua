local component = require("component")
local event = require("OCLib.event")
local internet = require("OCLib.internet")
local io = require("OCLib.io")

local meInterface = component.me_interface
local chatbox = component.chat_box

local json = require("Json")

local aiAssistant = {}

local chatCache = {}

local commandList = {
    "sendChatMessage",
    "appliedEnergisticsGetStoredItems"
}

local genConfig = {
    responseMimeType = "application/json",
    responseSchema = {
        type = "ARRAY",
        items = {
            type = "OBJECT",
            properties = {
                command = {
                    type = "STRING",
                    enum = commandList
                },
                args = {
                    type = "ARRAY",
                    items = {
                        type = "STRING"
                    },
                    minItems = 0
                }
            },
            required = { "command", "args" }
        }
    }
}

local context = [[
You are an assistant for a minecraft base in the Gregtech New Horizons modpack in minecraft.
You are connected to multiple peripherals.
You have access to these commands:
    - sendChatMessage: Send a message in the minecraft chat to communicate with players. Args: ( Message )
    - appliedEnergisticsGetStoredItems: Request all the stored items in the Applied Energistics network. Args: ( )
]]

function aiAssistant:processCommand(cmd, args)
    chatbox.say("Executing cmd: " .. cmd)

    if cmd == "sendChatMessage" then
        if #args > 0 then
            chatbox.say(args[1])
        else
            chatbox.say("sendChatMessage: Wrong arg amount")
        end
    elseif cmd == "appliedEnergisticsGetStoredItems" then
        local itemList = "Items in the AE network: \n"

        for item in meInterface.getItemsInNetwork() do
            itemList = itemList .. item.label .. " (Amount: " .. item.size .. ")\n"

            self:sendAIMessage(itemList)
        end
    end
end

function aiAssistant:sendAIMessage(msg)
    local geminiHttp =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    table.insert(chatCache, {
        role = "user",
        parts = {
            {
                text = msg
            }
        }
    })

    local jsonData = json.encode({
        system_instruction = {
            parts = {
                {
                    text = context
                }
            }
        },
        contents = chatCache,
        generationConfig = genConfig
    })

    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json",
        ["Content-Length"] = #jsonData,
        ["x-goog-api-key"] = "ADD YOUR API KEY HERE"
    }

    local response = internet.request(geminiHttp, jsonData, headers)

    local result = ""
    for chunk in response do result = result .. chunk end

    local responseJson = json.decode(result)

    local modelResponse = "No response text found."
    if responseJson and responseJson.contents and #responseJson.contents > 0 and responseJson.contents[1].parts and #responseJson.contents[1].parts > 0 then
        modelResponse = responseJson.contents[1].parts[1].text
    end

    table.insert(chatCache, {
        role = "model",
        parts = {
            {
                text = modelResponse
            }
        }
    })

    local file = io.open("/home/GTNH-AI/Cache.json", "w")

    io.write(file, json.encode(chatCache))

    for cmd in json.decode(modelResponse) do
        self.processCommand(cmd.command, cmd.args)
    end
end

function aiAssistant:messageReceived(id, _, sender, content)
    if not sender == "Diamond Assistant" and not content:find("^Asistant ") ~= nil then
        return
    end

    content = content:gsub("Assistant ")

    if content == "stop" then
        chatbox.say("Stopping AI Assistant!")

        event.ignore("chat_message", aiAssistant.messageReceived)
    else
        self:sendAIMessage(content)
    end
end

function aiAssistant.init()
    local file = io.open("/home/GTNH-AI/Cache.json", "r")

    chatCache = json.decode(io.read(file))
end

chatbox.setName("Diamond Assistant")

aiAssistant.init()

event.listen("chat_message", aiAssistant.messageReceived)
