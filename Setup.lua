local shell = require("shell")
local filesystem = require("filesystem")
local computer = require("computer")
local component = require("component")

local filesToDownload = {
    "https://raw.githubusercontent.com/Diamantino-Op/GTNH-AI-Assistant/refs/heads/main/AIAssistant.lua",
    "https://raw.githubusercontent.com/Diamantino-Op/GTNH-AI-Assistant/refs/heads/main/Json.lua"
}

filesystem.makeDirectory("/home/GTNH-AI")

shell.setWorkingDirectory("/home/GTNH-AI")

for _, file in ipairs(filesToDownload) do
    shell.execute("wget -f " .. file)
end

shell.setWorkingDirectory("/boot")

shell.execute(
    "wget -f https://raw.githubusercontent.com/Diamantino-Op/GTNH-AI-Assistant/refs/heads/main/99_start_ai.lua")
