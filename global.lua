--Source code history available at 
--https://github.com/DavidCarrington/terraforming_mars

guids = {
	start_button = 'bbd923',
	generation_counter = '1c4a11',
	generation_marker = 'a63f90',
	discard_one = '0e0cb2',
	discard_two = 'a55736',
	projects = '1ae58d',
	project_tile = 'b550fe',
	corporations = 'b17690',
	corporate_era_corporations = '658e8a',
	first_player_token = '2f276a',
	discard_one_token = 'f7e628'
}
	--[[city_bag = 'f38446'
	city_tile = '363d9f'
	greenery_bag = 'e4c505'
	greenery_tile = 'e93ab9'--]]

rockets_guids = { --these GUIDs are from state 2
	Red = 'c71edc',
	Yellow = '1290fb',
	Green = '6fbe62',
	Blue = 'da0da0',
	White = '6a16d5'
}

uninteractable_guids = {
	'7db564',
	'5458b5',
	'5c06aa',
	'fab25e',
	'94efa5',
	'b1cfa0',
	'c48e12',
	'583d53',
	'75192e',
	'31b4c1',
	'781713',
	'ca277c',
	'd38f51',
	'9ccd79',
	'988125',
	'97dd84'
}

things = {}

grid = {} -- game board as hexes centred on the marsian snap points

discardPile_x = -21
discardPile_y = 2
discardPile_z = -10.9
cards_required = 0

project_management_positions = {
	Yellow = {-16, 2.3, -35},
	Red = {16, 2.3, -35},
	White = {41, 4.5, -2.7},
	Blue = {16.2, 4.5, 35},
	Green = {-16, 4.5, 35}
}

first_player_positions = {
	White = {p={21.9, 2, -3.6},r={0,90,0},c={1,1,1}},
	Red = {p={15.6, 2, -17.5},r={0,180,0},c={0.856, 0.1, 0.094}},
	Yellow = {p={-15, 2, -17.4},r={0,180,0},c={0.905, 0.898, 0.172}},
	Green = {p={-14.9, 2, 18.5},r={0,0,0},c={0.192, 0.701, 0.168}},
	Blue = {p={15.6, 2, 18.5},r={0,0,0},c={0.118, 0.53, 1}}
}



function passFirstPlayerToken()
	local token = things['first_player_token']
	local first_player = token.getDescription()
	local players = mockGetSeatedPlayers()
	local player_order = {'White', 'Red', 'Yellow', 'Green', 'Blue'}
	
	if string.len(first_player) > 0 then		
		--Identify next player
		--TODO: find a more graceful way of achieving this!
		repeat
			first_player = getNextValueInTable(player_order, first_player)
		until Player[first_player] and Player[first_player].seated
	else
		--Pick someone at random
		first_player = players[math.random(#players)]
	end
	
	--Move the token
	local location = first_player_positions[first_player]
	token.setPositionSmooth(location.p)
	token.setRotationSmooth(location.r)
	
	--Announce
	if playerCount() > 1 then
		broadcastToAll('First player is ' .. first_player, location.c)
	end
	token.setDescription(first_player)
end

function onload ()
	math.randomseed( os.time() )

	buildGrid()

	for _, guid in pairs(uninteractable_guids) do
		getObjectFromGUID(guid).interactable = false
	end

	--Where are all the things?
	for name, guid in pairs(guids) do
		findThing(name)
		if not things[name] then
			displayError('Failed to find "'.. name ..'" on the board with GUID "' .. guid .. '"')
		end
	end
	
	--Create the Research button
	things['start_button'].createButton({
		click_function = 'performResearchClick',
		label = 'Research',
		function_owner = nil,
		position = { 0, 0.3, 0},
		rotation = {0, 180, 0},
		width = 800,
		height = 400,
		font_size = 200
	})	
end

function findThingByTable(table)
	return findThing(table['name'])
end

function findThing(name)
	local guid = guids[name]
	if guid then
		things[name] = getObjectFromGUID(guid)
	else
		displayError('No GUID registered for "'.. name)
	end
	return things[name]
end

function performResearchClick()
	startLuaCoroutine(Global, 'performResearch')
end

function rebuildProjectDeckFromDiscardPiles()
	local project_area = things['project_tile']
	local discard_one = findDeckInZone(things['discard_one'])
	local discard_two = findDeckInZone(things['discard_two'])

	if discard_one then
		combineDecks(discard_one, project_area)
	end
	if discard_two then
		combineDecks(discard_two, project_area)
	end
	
	wait(0.2)
	local project_deck = findDeckInZone(things['projects'])
	if project_deck and project_deck.getQuantity() > cards_required then
		project_deck.shuffle()
		wait(0.2)
		performResearch()
	else
		displayError('Failed making a new project deck. Are the discard piles empty?')
	end
	return 1
end

function combineDecksByTable(table)
	return combineDecks(
		table.source,
		table.destination
	)
end

function combineDecks(source, destination)
	local r = destination.getRotation()
	r.z = 180 --ensure decks are placed face-down
	source.setRotation(r)
	source.setPosition(destination.getPosition())
end

function performResearch()
	local project_deck = findDeckInZone(things['projects'])
	local generation_counter = things['generation_counter'].Counter
	local generation = generation_counter.getValue()
	local playerCount = playerCount()
	local research_limit = 4

	if generation == 0 then
		research_limit = 10
	end

	if generation == 0 and playerCount == 1 then
		soloSetup()
	end

	if generation >= 14 and playerCount == 1 then
		displayError('Solo game is limited to 14 generations. No more research available.')
	else
		cards_required = research_limit * playerCount
		if project_deck and project_deck.getQuantity() > cards_required then
			generation_counter.increment()
			if research_limit == 10 then
				dealTenProjectsAndTwoCorporations()
			else
				project_deck.dealToAll(research_limit)
			end
			moveGenerationMarker(generation+1)
			broadcastToAll('Generation ' .. (generation+1) .. ' has begun.', {1,1,1})
			passFirstPlayerToken()
			resetAllPassGenerationTokens()
		else
			rebuildProjectDeckFromDiscardPiles()
		end
	end
	return 1
end

function resetAllPassGenerationTokens()
	local rocket
	for _, guid in pairs(rockets_guids) do
		rocket = getObjectFromGUID(guid)
		if rocket then
			rocket.setState(1)
		end
	end
end

function displayError(message)
	broadcastToAll(message, {1,0,0})
end

function dealTenProjectsAndTwoCorporations()
	local project_deck = findDeckInZone(things['projects'])
	local corporation_deck = findThing('corporations')
	if not corporation_deck then
		corporation_deck = findThing('corporate_era_corporations')
	end
	if corporation_deck then
		corporation_deck.shuffle()
		wait(0.5)
	else
		displayError('Could not find a deck of corporations to deal out :(')
	end

	for colour, player_position in pairs(project_management_positions) do
		if Player[colour].seated then
			--10 projects
			for _ = 1, 10, 1 do
				project_deck.takeObject({
					position = player_position,
					flip = true
				});
			end

			--2 corporation cards - only if their hand is empty
			if isPlayerHandEmpty(colour) then
				corporation_deck.dealToColor(2, colour)
			end
		end
	end
end

function isPlayerHandEmpty(player)
	local objects = Player[player].getHandObjects()
	return not getNextValueInTable(objects)
end

function moveGenerationMarker(generation)
	local marker = things['generation_marker']
	local p = marker.getPosition()
	marker.setRotation({0,0,0})
	if generation <= 25 then
		p = {-16.9, 1.4, -13.9 + (generation * 1.16)}
	elseif generation <= 50 then
		p = {-16.9 + ((generation-25) * 1.37), 1.4, 15.1}
	end
	marker.setPositionSmooth(p)
end

function playerCount()
	local T = mockGetSeatedPlayers()
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function findDeckInZone(zone)
    local objectsInZone = zone.getObjects()
    for _, object in ipairs(objectsInZone) do
        if object.tag == "Deck" then
            return object
        end
    end
    return nil
end

function wait(time)
	local start = os.time()
	repeat coroutine.yield(0) until os.time() > start + time
end

function getNextValueInTable( t, value )
	local first
	local found = false
	for _,v in pairs(t) do
		if not first then
			first = v
		end
		if found then
			return v
		end
		if v == value then
			found = true
		end
	end
	return first
end

function mockGetSeatedPlayers()
	--return {'Red', 'Yellow', 'White', 'Green', 'Blue'}
	return getSeatedPlayers()
end


function buildGrid()

--builds the two dimensional array required for automatic city and greenspace placement
--makes use of hTD - horizontal Tile Delta, vTDL - vertical Tile Delta Left and vTDR - vertical Tile Delta Right to chart the 61 grid coordinates based on the coordinates of 4 snap points a1, a5, e1 and i5
--the type element holds information on the reserved or occupied status of a hex

	local a1 = {x= '-4.551478', y= '0.9611347', z= '8.95157051'} --top left snap point
	local grid_origin = a1
	local a5 = {x= '5.03584766', z= '8.972887'} --top right snap point
	local e1 = {x= '-9.27905', z= '0.721111536'} --left most snap point
	local i5 = {x= '5.06077766', z= '-7.62268'} --bottom right snap point

	local hTD = {x = (a5.x - a1.x)/4, z = (a5.z - a1.z)/4} --horizontal tile delta
	local vTDL = {x = (e1.x - a1.x)/4, z = (e1.z - a1.z)/4} --vertical left delta
	local vTDR = {x = (i5.x - a1.x)/8, z = (i5.z - a1.z)/8} --vertical right delta

	for i = 1, 9, 1 do
		grid[i] = {}
	end
	for i = 1, 61, 1 do
		if i < 6 then
			grid[1][i] = {x = grid_origin.x + hTD.x * (i - 1), y = grid_origin.y, z = grid_origin.z + hTD.z * (i - 1), type = checkTile(i)}
		elseif i < 12 then
			grid[2][i-5] = {x = grid_origin.x + vTDL.x + hTD.x * (i - 6), y = grid_origin.y, z = grid_origin.z +vTDL.z + hTD.z * (i - 6), type = checkTile(i)}
		elseif i < 19 then
			grid[3][i-11] = {x = grid_origin.x + vTDL.x * 2 + hTD.x * (i - 12), y = grid_origin.y, z = grid_origin.z +vTDL.z * 2 + hTD.z * (i - 12), type = checkTile(i)}
		elseif i < 27 then
			grid[4][i-18] = {x = grid_origin.x + vTDL.x * 3 + hTD.x * (i - 19), y = grid_origin.y, z = grid_origin.z +vTDL.z * 3 + hTD.z * (i - 19), type = checkTile(i)}
		elseif i < 36 then
			grid[5][i-26] = {x = grid_origin.x + vTDL.x * 4 + hTD.x * (i - 27), y = grid_origin.y, z = grid_origin.z +vTDL.z * 4 + hTD.z * (i - 27), type = checkTile(i)}
		elseif i < 44 then
			grid[6][i-35] = {x = grid_origin.x + vTDL.x * 4 + vTDR.x + hTD.x * (i - 36), y = grid_origin.y, z = grid_origin.z + vTDL.z * 4 + vTDR.z + hTD.z * (i - 36), type = checkTile(i)}
		elseif i < 51 then
			grid[7][i-43] = {x = grid_origin.x + vTDL.x * 4 + vTDR.x * 2 + hTD.x * (i - 44), y = grid_origin.y, z = grid_origin.z + vTDL.z * 4 + vTDR.z * 2 + hTD.z * (i - 44), type = checkTile(i)}
		elseif i < 57 then
			grid[8][i-50] = {x = grid_origin.x + vTDL.x * 4 + vTDR.x * 3 + hTD.x * (i - 51), y = grid_origin.y, z = grid_origin.z + vTDL.z * 4 + vTDR.z * 3 + hTD.z * (i - 51), type = checkTile(i)}
		else
			grid[9][i-56] = {x = grid_origin.x + vTDL.x * 4 + vTDR.x * 4 + hTD.x * (i - 57), y = grid_origin.y, z = grid_origin.z + vTDL.z * 4 + vTDR.z * 4 + hTD.z * (i - 57), type = checkTile(i)}
		end
	end
end

function checkTile(i)
--returns the base type of a hex
	if i == 2 or i == 4 or i == 5 or i == 11 or i == 26 or i == 30 or i == 31 or i == 32 or i == 41 or i == 42 or i == 43 or i == 61 then
		return 'ocean'
	elseif i == 29 then
		return 'noctis'
	else
		return 'land'
	end
end

function soloSetup()
--spawns two cities and an adjacent greenspace each on unoccupied, non-reserved space
--in the board game version the increment by which the cities are placed is decided by card values, this function just uses a random number between 1 and 30
	local city
	local greenspace
	local color

	cityPositions = {math.random(1,30), (49-math.random(1,30))}

	for index, value in pairs(cityPositions) do
		city = searchGrid('type', 'land', value)
		color = getRandomNotSeatedColor()
		--ensures that a legal hex has been found for a city
		--this could only fail if more than 19 hexes were occupied or reserved 
		--could be relevant for alternate game modes
		if city then
			placeTile(city.row, city.hex, 'city')
			placeTile(city.row, city.hex, color)
			greenspace = surveyGreenspace(city.row, city.hex)

			--ensures that a legal hex has been found for a greenspace adjacent to it's city
			if greenspace then
				placeTile(greenspace.row, greenspace.hex, 'greenspace')
				placeTile(greenspace.row, greenspace.hex, color)
			end
		end
	end
end

function getRandomNotSeatedColor()
	--returns a random not seated color for use on the neutral cities
	local colors = {'Red', 'Yellow', 'White', 'Green', 'Blue'}
	for index,color in pairs(colors) do
		if color == getSeatedPlayers()[1] then
			table.remove(colors, index)
		end
	end
	return colors[math.random(1,#colors)]
end

--iterates through rows, hexes in grid, until it has found key, value, frequency times and returns the row, hex of that space
--currently used to count viable, unoccupied, non-reserved spaces beginning in grid[1][1]
--currently somewhat underused, but could be relevant for alternate game modes
function searchGrid(key, value, frequency)
	local counter = 0
	for rowIndex, row in pairs(grid) do
		for hexIndex, hex in pairs(row) do
			if hex[key] == value then
				counter = counter + 1
				if counter == frequency then
					return {row = rowIndex, hex = hexIndex, x = hex.x, y = hex.y, z = hex.z}
				end
			end
		end
	end
	return false
end

--takes a tile from a loot bag and spawns a clone onto the grid
function placeTile (row, hex, type)
	local bag
	local tile
	
	if type == 'city' then
		bag = getObjectFromGUID('f38446') --city tile bag
		tile = bag.takeObject({guid = '363d9f'}) --city tile
	elseif type == 'greenspace' then
		bag = getObjectFromGUID('e4c505') --greenspace tile bag
		tile = bag.takeObject({guid = 'e93ab9'}) --greenspace tile
	elseif type == 'Red' then
		bag = getObjectFromGUID('12c991') --red player marker bag
		tile = bag.takeObject({guid = '17ec3f'}) --red player marker
	elseif type == 'Yellow' then
		bag = getObjectFromGUID('534757') --yellow player marker bag
		tile = bag.takeObject({guid = '606a5c'}) --yellow player marker
	elseif type == 'Green' then
		bag = getObjectFromGUID('6ae624') --green player marker bag
		tile = bag.takeObject({guid = '490585'}) --green player marker
	elseif type == 'Blue' then
		bag = getObjectFromGUID('7e9299') --blue player marker bag
		tile = bag.takeObject({guid = '4eeb0d'}) --blue player marker
	elseif type == 'White' then
		bag = getObjectFromGUID('4d3813') --white player marker bag
		tile = bag.takeObject({guid = 'c293b9'}) --white player marker
	end
	--this is a cop-out
	--I couldnt get the tiles to snap_to_grid when using the takeObject method
	--and i couldnt get the tiles inside the bag with getObjectFromGUID to clone them
	--so now im taking them out of the bag just long enough to clone amd destroy them
	tile.clone({
		snap_to_grid = true,
		position = {x = grid[row][hex].x, y = grid[row][hex].y, z = grid[row][hex].z}
		})
	tile.destruct()
	--adjusts the hex type so no other tiles are placed here
	grid[row][hex].type = type
end

--investigates the hexes surrounding a tile and returns grid coordinates for a randomly selected open space
function surveyGreenspace(rowIndex, hexIndex)
	local tiles = {}
	local orientation = {{-1,-1},{-1,0},{0,-1},{0,1},{1,0},{1,1}}
	local counter = 0
	local r
	local h

	--iterate through the six surrounding hexes, checking for viability
	for direction, delta in pairs(orientation) do
		r = rowIndex + delta[1]
		h = hexIndex + delta[2]

		--adjust the hex number when grid shifts below row 5
		if rowIndex > 5 then
			if r > rowIndex then 
				h = h - 1
			elseif r < rowIndex then 
				h = h + 1
			end
		elseif rowIndex == 5 then
			if r > rowIndex then
				h = h - 1
			end
		end

		--check if hex is in bounds
		if r > 0 and h > 0 and r < 10 and h <= #grid[r] then 
			--check if hex is not ocean, noctis, city or greenspace
			if grid[r][h].type == 'land' then
				counter = counter + 1
				tiles[counter] = {row = r, hex = h}
			end
		end
	end

	if counter > 0 then
		--select randomly among viable hexes
		local roll = math.random(1, counter)
		r = tiles[roll].row
		h = tiles[roll].hex

		--returns  row, hex of selected space
		return {row = r, hex = h}
	else
		return false
	end
end
