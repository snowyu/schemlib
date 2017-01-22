-- debug-print
local dprint = print
--local dprint = function() return end


local mapping = schemlib.mapping
local save_restore = schemlib.save_restore
local modpath = schemlib.modpath
local schematics = schemlib.schematics

--------------------------------------
--	Plan class
--------------------------------------
local plan = {}
plan.plan_list = {}

function plan.get(plan_id)
	if plan.plan_list ~= nil then
		return plan.plan_list[plan_id]
	end
end

function plan.get_all()
--TODO: list files + merge with plan_list
-- Output table entries:
-- entry[plan_id] = { plan_id=, status=, anchor_pos=, ground_y=, min_pos=, max_pos=, node_count= }
	return plan.plan_list
end

--------------------------------------
--	Create new plan object
--------------------------------------
plan.new = function( plan_id , anchor_pos)
	local self = {}
	self.plan_id = plan_id
	self.anchor_pos = anchor_pos
	self.data = {}
	self.status = "new"
--	self.plan_type = nil

	if self.plan_id ~= nil then
		plan.plan_list[self.plan_id] = self
	end

	--------------------------------------
	--Add node to plan
	--------------------------------------
	function self.add_node(self, node)
		-- insert new
		if self.data.scm_data_cache[node.y] == nil then
			self.data.scm_data_cache[node.y] = {}
		end
		if self.data.scm_data_cache[node.y][node.x] == nil then
			self.data.scm_data_cache[node.y][node.x] = {}
		end
		if self.data.scm_data_cache[node.y][node.x][node.z] == nil then
			self.data.nodecount = self.data.nodecount + 1
		else
			local replaced_node = self.data.scm_data_cache[node.y][node.x][node.z]
			data.nodeinfos[replaced_node.name_id].count = self.data.nodeinfos[replaced_node.name_id].count-1
		end

		if not node.name_id then
			local chk_name_id
			for name_id, nodeinfo in pairs(self.data.nodeinfos) do
				if nodeinfo.orig_name == node.name then
					chk_name_id = name_id
					nodeinfo.count = nodeinfo.count + 1
					break
				end
			end
			if not chk_name_id then
				chk_name_id = #self.data.nodeinfos + 1
				self.data.nodeinfos[chk_name_id] = { name_orig = node.name, count = 1 }
			end
			node.name_id = chk_name_id
		else
			self.data.nodeinfos[node.name_id].count = self.data.nodeinfos[node.name_id].count + 1
		end
		node.name = nil --standardize, in case it was given for id determination
		self.data.scm_data_cache[node.y][node.x][node.z] = node
	end

	--------------------------------------
	-- Get node from plan
	--------------------------------------
	function self.get_node(self, plan_pos)
		local pos = plan_pos
		assert(pos.x, "pos without xyz")
		if self.data.scm_data_cache[pos.y] == nil then
			return nil
		end
		if self.data.scm_data_cache[pos.y][pos.x] == nil then
			return nil
		end
		if self.data.scm_data_cache[pos.y][pos.x][pos.z] == nil then
			return nil
		end
		return self.data.scm_data_cache[pos.y][pos.x][pos.z]
	end

	--------------------------------------
	--Delete node from plan
	--------------------------------------
	function self.del_node(self, pos)
		if self.data.scm_data_cache[pos.y] ~= nil then
			if self.data.scm_data_cache[pos.y][pos.x] ~= nil then
				if self.data.scm_data_cache[pos.y][pos.x][pos.z] ~= nil then
					local oldnode = self.data.scm_data_cache[pos.y][pos.x][pos.z]
					self.data.nodeinfos[oldnode.name_id].count = self.data.nodeinfos[oldnode.name_id].count - 1
					self.data.nodecount = self.data.nodecount - 1
					self.data.scm_data_cache[pos.y][pos.x][pos.z] = nil
				end
				if next(self.data.scm_data_cache[pos.y][pos.x]) == nil then
					self.data.scm_data_cache[pos.y][pos.x] = nil
				end
			end
			if next(self.data.scm_data_cache[pos.y]) == nil then
				self.data.scm_data_cache[pos.y] = nil
			end
		end

		if self.data.prepared_cache and self.data.prepared_cache[pos.y] ~= nil then
			if self.data.prepared_cache[pos.y][pos.x]then
				if self.data.prepared_cache[pos.y][pos.x][pos.z] ~= nil then
					self.data.prepared_cache[pos.y][pos.x][pos.z] = nil
				end
				if next(self.data.prepared_cache[pos.y][pos.x]) == nil then
					self.data.prepared_cache[pos.y][pos.x] = nil
				end
			end
			if next(self.data.prepared_cache[pos.y]) == nil then
				self.data.prepared_cache[pos.y] = nil
			end
		end
	end

	--------------------------------------
	--Flood ta buildingplan with air
	--------------------------------------
	function self.apply_flood_with_air(self, add_max, add_min, add_top)
		self.data.ground_y =  math.floor(self.data.ground_y)
		add_max = add_max or 3
		add_min = add_min or 0
		add_top = add_top or 5

		-- cache air_id
		local air_id

		dprint("create flatting plan")
		for y = self.data.min_pos.y, self.data.max_pos.y + add_top do
			--calculate additional grounding
			if y > self.data.ground_y then --only over ground
				local high = y-self.data.ground_y
				add_min = high + 1
				if add_min > add_max then --set to max
					add_min = add_max
				end
			end

			dprint("flat level:", y)
			for x = self.data.min_pos.x - add_min, self.data.max_pos.x + add_min do
				for z = self.data.min_pos.z - add_min, self.data.max_pos.z + add_min do
					local airnode = {x=x, y=y, z=z, name = "air", name_id=air_id}
					if self:get_node(airnode) == nil then
						self:add_node(airnode)
						air_id = airnode.name_id
					end
				end
			end
		end
		dprint("flatting plan done")
	end

	--------------------------------------
	--Get world position relative to plan position
	--------------------------------------
	function self.get_world_pos(self,pos, anchor_pos)
		local apos = anchor_pos or self.anchor_pos
		return {	x=pos.x+apos.x,
						y=pos.y+apos.y - self.data.ground_y - 1,
						z=pos.z+apos.z
					}
	end

	--------------------------------------
	--Get plan position relative to world position
	--------------------------------------
	function self.get_plan_pos(self,pos, anchor_pos)
		local apos = anchor_pos or self.anchor_pos
		return {	x=pos.x-apos.x,
						y=pos.y-apos.y + self.data.ground_y + 1,
						z=pos.z-apos.z
					}
	end

	--------------------------------------
	--Get a random position of an existing node in plan
	--------------------------------------
-- get nodes for selection which one should be build
-- skip parameter is randomized
	function self.get_node_random(self)
		dprint("get something from list")

		-- get random existing y
		local keyset = {}
		for k in pairs(self.data.scm_data_cache) do table.insert(keyset, k) end
		if #keyset == 0 then --finished
			return nil
		end
		local y = keyset[math.random(#keyset)]

		-- get random existing x
		keyset = {}
		for k in pairs(self.data.scm_data_cache[y]) do table.insert(keyset, k) end
		local x = keyset[math.random(#keyset)]

		-- get random existing z
		keyset = {}
		for k in pairs(self.data.scm_data_cache[y][x]) do table.insert(keyset, k) end
		local z = keyset[math.random(#keyset)]

		if z ~= nil then
			return {x=x,y=y,z=z}
		end
	end

	--------------------------------------
	--Get a nodes list for a world chunk
	--------------------------------------
	function self.get_chunk_nodes(self, node)
	-- calculate the begin of the chunk
		--local BLOCKSIZE = core.MAP_BLOCKSIZE
		local BLOCKSIZE = 16
		local wpos = self:get_world_pos(node)
		local minp = {}
		minp.x = (math.floor(wpos.x/BLOCKSIZE))*BLOCKSIZE
		minp.y = (math.floor(wpos.y/BLOCKSIZE))*BLOCKSIZE
		minp.z = (math.floor(wpos.z/BLOCKSIZE))*BLOCKSIZE
		local maxp = vector.add(minp, 16)

		dprint("nodes for chunk (real-pos)", minetest.pos_to_string(minp), minetest.pos_to_string(maxp))

		local minv = self:get_plan_pos(minp)
		local maxv = self:get_plan_pos(maxp)
		dprint("nodes for chunk (plan-pos)", minetest.pos_to_string(minv), minetest.pos_to_string(maxv))

		local ret = {}
		for y = minv.y, maxv.y do
			if self.data.scm_data_cache[y] ~= nil then
				for x = minv.x, maxv.x do
					if self.data.scm_data_cache[y][x] ~= nil then
						for z = minv.z, maxv.z do
							if self.data.scm_data_cache[y][x][z] ~= nil then
								local pos = {x=x,y=y,z=z}
								local wpos = self:get_world_pos(pos)
								table.insert(ret, self:get_buildable_node(pos, wpos))
							end
						end
					end
				end
			end
		end
		dprint("nodes in chunk to build", #ret)
		return ret
	end

	--------------------------------------
	-- Generate a plan from schematics file
	--------------------------------------
	function self.read_from_schem_file(self, filename)
		local file = save_restore.file_access(filename, "r")
		if file == nil then
			dprint("error: could not open file \"" .. filename .. "\"")
			self.data = nil
		else
			-- different file types
			if string.find( filename, '.mts',  -4 ) then
				self.data = schematics.analyze_mts_file(file)
			end
			if string.find( filename, '.we',   -3 ) or string.find( filename, '.wem',  -4 ) then
				self.data = schematics.analyze_we_file(file)
			end
		end
	end

	--------------------------------------
	-- Get a node ready to place
	--------------------------------------
	function self.get_buildable_node(self, plan_pos, world_pos)
		-- first run, generate mapping data
		if self.data.mappedinfo == nil then
			mapping.do_mapping(self.data)
		end

		-- get from cache
		if self.data.prepared_cache ~= nil and
				self.data.prepared_cache[plan_pos.y] ~= nil and
				self.data.prepared_cache[plan_pos.y][plan_pos.x] ~= nil and
				self.data.prepared_cache[plan_pos.y][plan_pos.x][plan_pos.z] ~= nil then
			return self.data.prepared_cache[plan_pos.y][plan_pos.x][plan_pos.z]
		end

		-- get scm data
		local scm_node = self:get_node(plan_pos)
		if scm_node == nil then
			return nil
		end

		--get mapping data
		local map = self.data.mappedinfo[scm_node.name_id]
		if map == nil then
			return nil
		end

		local node = mapping.merge_map_entry(map, scm_node)

		if node.custom_function ~= nil then
			node.custom_function(node, plan_pos, world_pos)
		end

		-- maybe node name is changed in custom function. Update the content_id in this case
		node.content_id = minetest.get_content_id(node.name)
		node.node_def = minetest.registered_nodes[node.name]
		node.plan_pos = plan_pos
		node.world_pos = world_pos

		-- store the mapped node info in cache
		if self.data.prepared_cache == nil then
			self.data.prepared_cache = {}
		end
		if self.data.prepared_cache[plan_pos.y] == nil then
			self.data.prepared_cache[plan_pos.y] = {}
		end
		if self.data.prepared_cache[plan_pos.y][plan_pos.x] == nil then
			self.data.prepared_cache[plan_pos.y][plan_pos.x] = {}
		end
		self.data.prepared_cache[plan_pos.y][plan_pos.x][plan_pos.z] = node

		return node
	end

	--------------------------------------
	--Delete / remove the whole plan
	--------------------------------------
	function self.delete_plan(self)
		if self.plan_id then
			plan.plan_list[self.plan_id ] = nil
		end
	end

	--------------------------------------
	--Change the plan id
	--------------------------------------
	function self.change_plan_id(self, new_plan_id)
		if self.plan_id then
			plan.plan_list[self.plan_id ] = nil
		end
		self.plan_id = new_plan_id
		if self.plan_id then
			plan.plan_list[self.plan_id ] = self
		end
	end

	--------------------------------------
	--Propose anchor position for the plan
	--------------------------------------
	function self.propose_anchor(self, world_pos, do_check, add_y, add_xz)
		add_xz = add_xz or 3
		add_y = add_y or 5
		local minp = self:get_world_pos(self.data.min_pos, world_pos)
		local maxp = self:get_world_pos(self.data.max_pos, world_pos)

		-- to get some randomization for error-node
		local minx, maxx, stx, minz, maxz, stz
		if math.random(2) == 1 then
			minx = minp.x-add_xz
			maxx = maxp.x+add_xz
		else
			maxx = minp.x-add_xz
			minx = maxp.x+add_xz
		end
		if math.random(2) == 1 then
			minz = minp.z-add_xz
			maxz = maxp.z+add_xz
		else
			maxz = minp.z-add_xz
			minz = maxp.z+add_xz
		end
		-- handle rotation
		if minx < maxx then
			stx = 1
		else
			stx = -1
		end
		if minz < maxz then
			stz = 1
		else
			stz = -1
		end

		-- TODO: check for overlaps to other not builded plans
		-- TODO: get the additional values as parameter
		local function is_vegetation(nodedef)
			if nodedef.groups.leaves or
					nodedef.groups.leafdecay or
					nodedef.groups.tree then
				return true
			else
				return false
			end
		end

		-- only "y" needs to be proposed as usable ground
		local ground_y
		local groundnode_count = 0

		for x = minx, maxx, stx do
			for z = minz, maxz, stz do
				local is_ground = true
				for y = minp.y-add_y, maxp.y+add_y, 1 do
					local pos = {x=x, y=y, z=z}
					local node = minetest.get_node(pos)
					if node.name == "ignore" then
						minetest.get_voxel_manip():read_from_map(pos, pos)
						node = minetest.get_node(pos)
					end
					local nodedef = minetest.registered_nodes[node.name]
					if do_check and nodedef and
							nodedef.is_ground_content == false and -- override denied
							is_vegetation(nodedef) == false then -- allow removal of trees
						dprint("build denied because of not overridable", node.name, "at", x..':'..z)
						return false, {x=x, y=y, z=z}
					end

					if 	node.name == "air" or node.name == "default:snowblock" or
							nodedef and (nodedef.walkable == false or nodedef.drawtype == "airlike" or is_vegetation(nodedef)) then
						if y == minp.y-add_y then
							dprint("build denied because hanging in air at", x..':'..z)
							return false, {x=x, y=y, z=z}
						end
						if is_ground == true then --only if ground above
							groundnode_count = groundnode_count + 1
							if groundnode_count == 1 then
								ground_y = pos.y
							else
								ground_y = ground_y + (pos.y - ground_y) / groundnode_count
							end
							if not do_check == true then
								break -- leave y loop, not necessary to check above
							end
						end
						is_ground = false
					end
				end
				if is_ground ~= false then --nil is air only (no ground), true is ground only (no air)
					-- air only or non-air only. Not buildable
					dprint("build denied because ground only at", x..':'..z)
					return false, {x=x, y=world_pos.y, z=z}
				end
			end
		end

		if ground_y then
--TODO: additional do_check of maybe existing delta to new ground_y is not implemented!
			return {x=world_pos.x, y=math.floor(ground_y+0.5), z=world_pos.z}
		end
	end

	--------------------------------------
	-- add/build a node
	--------------------------------------
	function self.do_add_node(self, buildable_node)
		if buildable_node.node then
			minetest.env:add_node(buildable_node.world_pos, buildable_node.node)
			if buildable_node.node.meta then
				minetest.env:get_meta(buildable_node.world_pos):from_table(buildable_node.node.meta)
			end
		end
		self:del_node(buildable_node.plan_pos)
	end

	--------------------------------------
	--add/build a chunk
	--------------------------------------
	function self.do_add_chunk(self, plan_pos)
		local chunk_pos = self.plan:get_world_pos(plan_pos)
		dprint("---build chunk", minetest.pos_to_string(plan_pos))

		local chunk_nodes = self:get_chunk_nodes(self:get_plan_pos(chunk_pos))
		dprint("Instant build of chunk: nodes:", #chunk_nodes)
		for idx, nodeplan in ipairs(chunk_nodes) do
			--TODO: call "add_node"
			self:do_add_node(nodeplan)
		end
	end

	--------------------------------------
	---add/build a chunk using VoxelArea
	--------------------------------------
	function self.do_add_chunk_voxel(self, plan_pos)
		local chunk_pos = self.plan:get_world_pos(plan_pos)
		dprint("---build chunk uning voxel", minetest.pos_to_string(plan_pos))

		-- work on VoxelArea
		local vm = minetest.get_voxel_manip()
		local minp, maxp = vm:read_from_map(chunk_pos, chunk_pos)
		local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
		local data = vm:get_data()
		local param2_data = vm:get_param2_data()
		local light_fix = {}
		local meta_fix = {}
--		for idx in a:iterp(vector.add(minp, 8), vector.subtract(maxp, 8)) do -- do not touch for beter light update
		for idx, origdata in pairs(data) do -- do not touch for beter light update
			local wpos = a:position(idx)
			local pos = self:get_plan_pos(wpos)
			local node = self:get_buildable_node(pos, wpos)
			if node and node.content_id then
				-- write to voxel
				data[idx] = node.content_id
				param2_data[idx] = node.param2

				-- mark for light update
				assert(node.node_def, dump(node))
				if node.node_def.light_source and node.node_def.light_source > 0 then
					table.insert(light_fix, node)
				end
				if node.meta then
					table.insert(meta_fix, node)
				end
				self.plan:remove_node(node)
			end
			self.plan:remove_node(pos) --if exists
		end

		-- store the changed map data
		vm:set_data(data)
		vm:set_param2_data(param2_data)
		vm:calc_lighting()
		vm:update_liquids()
		vm:write_to_map()
		vm:update_map()

		-- fix the lights
		dprint("fix lights", #light_fix)
		for _, fix in ipairs(light_fix) do
			minetest.env:add_node(fix.world_pos, fix)
		end

		dprint("process meta", #meta_fix)
		for _, fix in ipairs(meta_fix) do
			minetest.env:get_meta(fix.world_pos):from_table(fix.meta)
		end
	end
	--------------------------------------

	--------------------------------------
--	TODO: save the reference to a global accessable table
	--------------------------------------
	return self -- the plan object
end

return plan
