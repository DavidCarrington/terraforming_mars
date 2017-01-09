function onload ()
    self.createButton({
        click_function = 'click',
        label = 'Discard',
        function_owner = self,
        position = { 0, 0.3, 0},
        rotation = {0, 180, 0},
        width = 800,
        height = 400,
        font_size = 200
    })
end

function click(_, colour)
    local hand = Player[colour].getHandObjects()
    local discard_area = Global.call('findThingByTable', {name='discard_one_token'})
    for _, card in pairs(hand) do
        Global.call('combineDecksByTable', {
            source=card,
            destination=discard_area
        })
    end
end