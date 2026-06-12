mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace   = "testing",
    mp          = true
}
mods["SmoothSpatula-TomlHelper"].auto()
params = {
    pause_key = 80 -- P
}
params = Toml.config_update(_ENV["!guid"], params)

gui.add_to_menu_bar(function()
    local isChanged, keybind_value = ImGui.Hotkey("Pause Key", params['pause_key'])
    if isChanged then
        params['pause_key'] = keybind_value
        Toml.save_cfg(_ENV["!guid"], params)
    end
end)

local heartbeat = 60
local pause_sprite = nil

function init()
    local packet = Packet.new("pausePacket")
    local packet_serializer = function(buffer, frame_sync)
    end
    local packet_deserializer = function(buffer)
        toggle_pause()
    end
    packet:set_serializers(packet_serializer, packet_deserializer)

    gui.add_always_draw_imgui(function()
        if not Net.online or not gm._mod_game_ingame() then return end

        if gm.variable_global_get("pause") then
            local oClient = gm.instance_find(gm.constants.oClient, 0)
            if oClient ~=-4 then 
                oClient.timeout = 0
            end
        end

        if ImGui.IsKeyPressed(params['pause_key']) then
            local oInit = gm.instance_find(gm.constants.oInit, 0)
            if oInit and oInit.chat_talking then return end
            packet:send_to_all(packet)
            toggle_pause()
        end
        heartbeat = heartbeat - 1
        if heartbeat < 20 then
            gm.server_message_send(0, 0, -4)
            heartbeat = 60
        end 

    end)
end

-- Funcs --

function custom_pause()

    -- print(Global._current_frame)
    -- print(gm.time_source_get_units(1))

    gm.variable_global_set("pause", true)

    local oInit = gm.instance_find(gm.constants.oInit, 0)
    if oInit and oInit.chat_talking then
        gm.virtual_keyboard_hide()
        oInit.chat_talking = false
    end
    --     with (pEmoteInterface)
    --         instance_destroy();

    gm.variable_global_set("gameplay_paused", true)
    gm.audio_pause_all()
    gm.part_system_automatic_update(gm.variable_global_get("partsys_damage"), false)
    gm.part_system_automatic_update(gm.variable_global_get("partsys_damage_above"), false)
    gm.part_system_automatic_update(gm.variable_global_get("above"), false)
    gm.part_system_automatic_update(gm.variable_global_get("below"), false)
    gm.part_system_automatic_update(gm.variable_global_get("middle"), false)
    gm.part_system_automatic_update(gm.variable_global_get("very_below"), false)

        local display_surface = gm.variable_global_get("display_surface")
        if gm.surface_exists(display_surface) then
           pause_sprite = gm.sprite_create_from_surface(display_surface, 0, 0, gm.surface_get_width(display_surface), gm.surface_get_height(display_surface), 0, 0, 0, 0)
        end

        gm.time_source_pause(1) -- time_source_game = 1.0
        gm.instance_deactivate_all(true)
        gm.instance_activate_object(gm.constants.oInit)
        gm.instance_activate_object(gm.constants.oConsole)
        gm.instance_activate_object(gm.constants.oSteamMultiplayer)
        gm.instance_activate_object(gm.constants.oControllerDisconnectConfirmation)
        gm.instance_activate_object(gm.constants.oClient)
        gm.instance_activate_object(gm.constants.oServer)
end

function custom_unpause()
    gm.variable_global_set("pause", false)
    pause_sprite = nil
    
    if gm.variable_global_get("gameplay_paused") == true then
        gm.audio_resume_all();
        gm.part_system_automatic_update(gm.variable_global_get("partsys_damage"), true)
        gm.part_system_automatic_update(gm.variable_global_get("partsys_damage_above"), true)
        gm.part_system_automatic_update(gm.variable_global_get("above"), true)
        gm.part_system_automatic_update(gm.variable_global_get("below"), true)
        gm.part_system_automatic_update(gm.variable_global_get("middle"), true)
        gm.part_system_automatic_update(gm.variable_global_get("very_below"), true)
        gm.time_source_resume(1);

        gm.instance_activate_all();
        gm.variable_global_set("gameplay_paused", false)
    end
end

function toggle_pause()
    if not gm.variable_global_get("pause") then 
        custom_pause()
        print("Game Paused")
    else
        custom_unpause()
        print("Game Unpaused")
    end
end

Initialize.add_hotloadable(init)

-- Hooks --

Callback.add(Callback.POST_HUD_DRAW, function()
    if gm.variable_global_get("pause") then

        local cam = gm.view_get_camera(0)
        local w = gm.camera_get_view_width(cam)
        local h = gm.camera_get_view_height(cam)
        local scale = gm.prefs_get_zoom_scale()

        if pause_sprite then
            gm.ui_force_render_zoom(1, 0, 0, false, 1);
            gm.draw_sprite_stretched(pause_sprite, 0, 0, 0, gm.variable_global_get("___view_l_w"), gm.variable_global_get("___view_l_h"))

            gm.scribble_set_starting_format("fntSquareLarge", 8114927, 0)
            gm.scribble_draw(
                w*0.5 * scale - gm.scribble_get_width("GAME PAUSED")/2,
                h*0.45 * scale , "GAME PAUSED")
            gm.scribble_draw(
                w*0.5 * scale - gm.scribble_get_width("TO UNPAUSE")/2 + 15,
                h*0.54 * scale , "TO UNPAUSE")
            gm.draw_sprite_stretched(gm.keyboard_key_get_sprite("P", 1), 0,
                w*0.5 * scale - gm.scribble_get_width("TO UNPAUSE")/2 - 25,
                h*0.54 * scale - 5, 30, 30)
            gm.ui_reset_render_zoom();
        end
    end
end)

gm.post_script_hook(gm.constants.server_message_send, function(self, other, result, args)
    heartbeat = 60
end)