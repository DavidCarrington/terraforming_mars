-- Source code history available at 
-- https://github.com/DavidCarrington/terraforming_mars

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
	first_player_token = '2f276a'
}

rockets_guids = { -- these GUIDs are from state 2
	Red = 'c71edc',
	Yellow = '1290fb',
	Green = '6fbe62',
	Blue = 'da0da0',
	White = '6a16d5'
}

things = {}

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
		-- Identify next player
		-- TODO: find a more graceful way of achieving this!
		repeat
			first_player = getNextValueInTable(player_order, first_player)
		until Player[first_player] and Player[first_player].seated
	else
		-- Pick someone at random
		first_player = players[math.random(#players)]
	end
	
	-- Move the token
	local location = first_player_positions[first_player]
	token.setPositionSmooth(location.p)
	token.setRotationSmooth(location.r)
	
	-- Announce
	if playerCount() > 1 then
		broadcastToAll('First player is ' .. first_player, location.c)
	end
	token.setDescription(first_player)
end

function onload ()
	math.randomseed( os.time() )

	-- Where are all the things?
	for name, guid in pairs(guids) do
		things[name] = getObjectFromGUID(guid)
		if not things[name] then
			displayError('Failed to find "'.. name ..'" on the board with GUID "' .. guid .. '"')
		end
	end
	
	-- Create the Research button
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

function combineDecks(source, destination)
	local r = destination.getRotation()
	r.z = 180 -- ensure decks are placed face-down
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
	local corporation_deck = things['corporations']
	if not corporation_deck then
		corporation_deck = things['corporate_era_corporations']
	end
	if corporation_deck then
		corporation_deck.shuffle()
		wait(0.5)
	else
		displayError('Could not find a deck of corporations to deal out :(')
	end

	for colour, player_position in pairs(project_management_positions) do
		if Player[colour].seated then
			-- 10 projects
			for _ = 1, 10, 1 do
				project_deck.takeObject({
					position = player_position,
					flip = true
				});
			end

			-- 2 corporation cards - only if their hand is empty
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
	-- return {'Red', 'Yellow', 'White', 'Green', 'Blue'}
	return getSeatedPlayers()
end
