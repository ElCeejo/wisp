wisp = {}

wisp.wisps = {}
wisp.jars = {}

-----------------
-- Mod Storage --
-----------------

local mod_storage = minetest.get_mod_storage()

local data = {
    wisps = minetest.deserialize(mod_storage:get_string("wisps")) or {},
    jars = minetest.deserialize(mod_storage:get_string("jars")) or {},
}

local function save()
    mod_storage:set_string("wisps", minetest.serialize(data.wisps))
    mod_storage:set_string("jars", minetest.serialize(data.jars))
end

minetest.register_on_shutdown(save)
minetest.register_on_leaveplayer(save)

local function periodic_save()
    save()
    minetest.after(120, periodic_save)
end
minetest.after(120, periodic_save)

wisp.wisps = data.wisps
wisp.jars = data.jars

----------
-- Math --
----------

local random = math.random
local abs = math.abs
local function interp(a, b, w) return a + (b - a) * w end

local function wisp_visual(pos, color)
    local random_vel = {
        x = random(-1, 1),
        y = -1,
        z = random(-1, 1)
    }
    local random_offset = {
        x = pos.x + (random(-1, 1) * 0.1),
        y = pos.y + (random(-1, 1) * 0.1),
        z = pos.z + (random(-1, 1) * 0.1)
    }
    minetest.add_particle({
        pos = random_offset,
        velocity = random_vel,
        acceleration = {
            x = 0,
            y = random(6, 8),
            z = 0,
        },
        expirationtime = 0.1,
        size = random(3, 5),
        texture = "wisp_".. color .. ".png",
        glow = 6
    })
end

local function wisped_effect(pos, color)
    minetest.add_particlespawner({
        amount = 2,
        time = 0.1,
        minpos = vector.subtract(pos, 0.5),
        maxpos = vector.add(pos, 0.5),
        minvel = {
            x = -0.5,
            y = 0.5,
            z = -0.5
        },
        maxvel = {
            x = 0.5,
            y = 1,
            z = 0.5
        },
        minacc = {
            x = 0,
            y = 2,
            z = 0
        },
        maxacc = {
            x = 0,
            y = 4,
            z = 0
        },
        minexptime = 0.5,
        maxexptime = 1,
        minsize = 1,
        maxsize = 2,
        collisiondetection = false,
        texture = "wisp_" .. color .. "_particle.png",
        glow = 6
    })
end

---------
-- API --
---------

local wisp_colors = {
    "red",
    "green",
    "blue",
}

local function create_wisp(pos, color)
    local wisp_color = color
    if not color
    or string.len(color) == 0 then
        wisp_color = wisp_colors[random(3)]
    end
    local wisp_d = {
        pos = pos,
        new_pos = pos,
        self_dtime = 0,
        lifetime = 0,
        color = wisp_color
    }
    table.insert(wisp.wisps, wisp_d)
end

minetest.register_chatcommand("add_wisp", {
	params = "<color>",
	description = "Spawns a Wisp",
    privs = {server = true},
	func = function(name, color)
        local pos = minetest.get_player_by_name(name):get_pos()
		create_wisp(pos, color)
	end,
})

minetest.register_chatcommand("clear_wisps", {
	params = "<color>",
	description = "Clears Wisps",
    privs = {server = true},
	func = function(name, color)
        wisp.wisps = {}
	end,
})


minetest.register_globalstep(function(dtime)
    for i = 1, #wisp.wisps do
        local c_wisp = wisp.wisps[i]
        if not c_wisp then return end
        local pos = c_wisp.pos
        local color = c_wisp.color
        local lifetime = c_wisp.lifetime or 0
        local self_dtime = c_wisp.self_dtime or 0
        local move_time = c_wisp.move_time or 0
        lifetime = lifetime + dtime
        wisp_visual(pos, color)
        c_wisp.self_dtime = self_dtime + dtime
        if self_dtime > 0.1 then
            -- Movement
            move_time = move_time + 0.1
            if move_time > 2 then
                if random(3) > 1 then
                    local new_pos = vector.add(pos, random(-3, 3))
                    if minetest.get_node(new_pos).name == "air" then
                        c_wisp.new_pos = new_pos
                    end
                else
                    move_time = 0
                end
            end
            if vector.distance(pos, c_wisp.new_pos) > 0.2 then
                c_wisp.pos = {
                    x = interp(pos.x, c_wisp.new_pos.x, 0.05),
                    y = interp(pos.y, c_wisp.new_pos.y, 0.05),
                    z = interp(pos.z, c_wisp.new_pos.z, 0.05)
                }
            end
            -- Left-click detection
            local objects = minetest.get_objects_inside_radius(pos, 6)
            for n = 1, #objects do
                local obj = objects[n]
                if obj
                and obj:is_player() then
                    local p_pos = obj:get_pos()
                    p_pos.y = p_pos.y + 1.4
                    local dir = vector.direction(p_pos, pos)
                    local flee_dir = {
                        x = dir.x,
                        y = random(-1, 1),
                        z = dir.z
                    }
                    c_wisp.new_pos = vector.add(pos, flee_dir)
                    if obj:get_player_control().LMB
                    and obj:get_wielded_item():get_name() == "wisp:jar" then
                        local look_dir = obj:get_look_dir()
                        if math.abs(vector.length(vector.subtract(dir, look_dir))) < 0.1 then
                            obj:set_wielded_item("wisp:jar_" .. color)
                            table.remove(wisp.wisps, i)
                        end
                    end
                end
            end
            self_dtime = 0
        end
        if lifetime > 60 then
            table.remove(wisp.wisps, i)
        end
    end
    for i = 1, #wisp.jars do
        if not wisp.jars[i] then return end
        local pos = wisp.jars[i].pos
        if minetest.get_node(pos).name == "ignore"
        or minetest.get_node(pos).name:match("^wisp:jar_") then
            local color = wisp.jars[i].color
            wisp_visual(pos, color)
            if color == "green"
            and random(256) < 2 then
                local nodes = minetest.find_nodes_in_area_under_air(vector.subtract(pos, 5), vector.add(pos, 5), {"group:grass", "group:plant", "group:flora"})
                if #nodes > 0 then
                    for n = 1, #nodes do
                        grow_crops(nodes[n], minetest.get_node(nodes[n]).name)
                    end
                end
            end
            if color == "blue"
            and random(64) < 2 then
                local nodes = minetest.find_nodes_in_area_under_air(vector.subtract(pos, 5), vector.add(pos, 5), "group:fire")
                if #nodes > 0 then
                    for n = 1, #nodes do
                        minetest.remove_node(nodes[n])
                        wisped_effect(nodes[n], color)
                    end
                end
            end
            if color == "red"
            and random(64) < 2 then
                local nodes = minetest.find_nodes_in_area_under_air(vector.subtract(pos, 5), vector.add(pos, 5), {"group:grass", "group:plant", "group:flora"})
                if #nodes > 0 then
                    for n = 1, #nodes do
                        minetest.remove_node(nodes[n])
                        wisped_effect(nodes[n], color)
                    end
                end
            end
        else
            table.remove(wisp.jars, i)
        end
    end
end)

minetest.register_abm({
    label = "wisp:spawning",
    nodenames = {"group:tree"},
    neighbors = {"air"},
    interval = 120,
    chance = 512,
    action = function(pos)
        create_wisp(vector.add(pos, random(-3, 3)))
    end
})

-----------
-- Nodes --
-----------

minetest.register_node("wisp:jar", {
    description = "Jar",
    inventory_image = "wisp_jar_inv.png",
    wield_image = "wisp_jar_inv.png",
    drawtype = "mesh",
    mesh = "wisp_jar.obj",
    tiles = {"wisp_jar.png"},
    paramtype = "light",
    sunlight_propagates = true,
    selection_box = {
        type = "fixed",
        fixed = {-0.315, -0.5, -0.315, 0.315, 0.265, 0.315},
    },
    collision_box = {
        type = "fixed",
        fixed = {-0.315, -0.5, -0.315, 0.315, 0.265, 0.315},
    },
    groups = {cracky = 1, oddly_breakable_by_hand = 2},
    stack_max = 1
})

for i = 1, 3 do
    local color = wisp_colors[i]
    minetest.register_node("wisp:jar_" .. color, {
        description = "Jar with " .. color .. " Wisp",
        inventory_image = "wisp_jar_" .. color .. "_inv.png",
        wield_image = "wisp_jar_" .. color .. "_inv.png",
        drawtype = "mesh",
        mesh = "wisp_jar.obj",
        tiles = {"wisp_jar.png"},
        paramtype = "light",
        sunlight_propagates = true,
        selection_box = {
            type = "fixed",
            fixed = {-0.315, -0.5, -0.315, 0.315, 0.265, 0.315},
        },
        collision_box = {
            type = "fixed",
            fixed = {-0.315, -0.5, -0.315, 0.315, 0.265, 0.315},
        },
        groups = {cracky = 1, oddly_breakable_by_hand = 2},
        stack_max = 1
    })
    minetest.register_on_placenode(function(pos, newnode)
        if newnode.name == "wisp:jar_" .. color then
            table.insert(wisp.jars, {pos = pos, color = color})
        end
    end)
end

function grow_crops(pos, nodename)
    local checkname = nodename:sub(1, string.len(nodename) - 1)
    if minetest.registered_nodes[checkname .. "1"]
    and minetest.registered_nodes[checkname .. "2"]
    and minetest.registered_nodes[checkname .. "2"].drawtype == "plantlike" then -- node is more than likely a plant
        local stage = tonumber(string.sub(nodename, -1)) or 0
        local newname = checkname .. (stage + 1)
        if minetest.registered_nodes[newname] then
            local def = minetest.registered_nodes[newname]
            def = def and def.place_param2 or 0
            minetest.set_node(pos, {name = newname, param2 = def})
            minetest.add_particlespawner({
                amount = 6,
                time = 0.1,
                minpos = vector.subtract(pos, 0.5),
                maxpos = vector.add(pos, 0.5),
                minvel = {
                    x = -0.5,
                    y = 0.5,
                    z = -0.5
                },
                maxvel = {
                    x = 0.5,
                    y = 1,
                    z = 0.5
                },
                minacc = {
                    x = 0,
                    y = 2,
                    z = 0
                },
                maxacc = {
                    x = 0,
                    y = 4,
                    z = 0
                },
                minexptime = 0.5,
                maxexptime = 1,
                minsize = 1,
                maxsize = 2,
                collisiondetection = false,
                vertical = false,
                use_texture_alpha = true,
                texture = "wisp_green_particle.png",
                glow = 6
            })
        end
    end
end

--------------
-- Crafting --
--------------

if minetest.get_modpath("nc_optics")
and minetest.get_modpath("nc_tree") then
    nodecore.register_craft({
		label = "assemble jar",
		normal = {y = 1},
		indexkeys = {"nc_optics:shelf", "nc_tree:stick"},
		nodes = {
			{match = "nc_tree:stick", replace = "air"},
			{y = -1, match = "nc_optics:shelf", replace = "wisp:jar"}
		}
	})
else
    minetest.register_craft({
        output = "wisp:jar",
        recipe = {
            {"group:glass", "group:wood", "group:glass"},
            {"group:glass", "", "group:glass"},
            {"group:glass", "group:glass", "group:glass"}
        }
    })
end