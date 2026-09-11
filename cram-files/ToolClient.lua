local player = game:GetService("Players").LocalPlayer

tool.Equipped:Connect(function()
    local pgui = player:FindFirstChild("PlayerGui")
    if not pgui then return end
    local ui = pgui:FindFirstChild("MasterCRAMUI")
    if ui then
        ui.Enabled = true
        local mf = ui:FindFirstChild("MainFrame")
        if mf then
            mf.Visible = true
        end
        local tb = ui:FindFirstChild("TogglePanelBtn")
        if tb then
            tb.Visible = true
        end
        local remote = tool:FindFirstChild("MasterRemote")
        if remote then
            remote:FireServer("RequestFullState", {})
        end
    end
end)

tool.Unequipped:Connect(function()
    local pgui = player:FindFirstChild("PlayerGui")
    if not pgui then return end
    local ui = pgui:FindFirstChild("MasterCRAMUI")
    if ui then
        local mf = ui:FindFirstChild("MainFrame")
        if mf then
            mf.Visible = false
        end
        local tb = ui:FindFirstChild("TogglePanelBtn")
        if tb then
            tb.Visible = false
        end
    end
end)


