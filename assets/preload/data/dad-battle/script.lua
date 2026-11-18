-- Erect Mode install: this script belongs to the Erect/Nightmare takes only,
-- 0.6.3 loads data/<song>/*.lua for every difficulty, so wrap the whole file.
if difficultyPath == 'erect' or difficultyPath == 'nightmare' then
-- Just a little something to prevent the 'Dadbattle Spotlight' event to interfere with the camera zoom.
function onEvent(eventName, value1, value2, strumTime)
    if eventName == 'Dadbattle Spotlight' then
        if value1 == '0' then
            setProperty('defaultCamZoom', getProperty('defaultCamZoom') + 0.12)
        elseif value1 == '1' then
            setProperty('defaultCamZoom', getProperty('defaultCamZoom') - 0.12)
        end
    end
end
end -- Erect/Nightmare only
