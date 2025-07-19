local component = require("component")
local event = require("event")
local internet = require("internet")

local json = require("Json")

local chatbox = component.chat_box

local chatCache = {}

local function sendAIMessage(msg)
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

    local context = "You are an assistant for a minecraft base in the Gregtech New Horizons modpack in minecraft."

    local jsonData = json.encode({
        system_instruction = {
            parts = {
                {
                    text = context
                }
            }
        },
        contents = chatCache
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

    chatbox.say(modelResponse)
end

local function messageReceived(id, _, sender, content)
    if content == "stop" then
        chatbox.say("Stopping AI Assistant!")

        event.ignore("chat_message", messageReceived)
    else
        sendAIMessage(content)
    end
end

chatbox.setName("Diamond Assistant")

event.listen("chat_message", messageReceived)
