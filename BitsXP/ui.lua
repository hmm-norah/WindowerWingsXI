UI = {
  settings = nil,
  jobInfo = {
    level = 0,
    primaryJob = '',
    secondaryJob = '',
  },
  xp = {
    current = 0,
    max = 0,
    remaining = 0,
  },
  session = {
    startTime = nil,
    xpEarned = 0,
    xpRatePerSecond = 0,
    xpRatePerHour = 0,
    estimatedTimeToLevelSeconds = 0,
    nextChain = {
      number = 0,
      deadline = nil,
    },
  },
}

local frameCount = 0
local box = nil

function setupUI()
  if box ~= nil then
    return
  end

  box = texts.new('${current_string}', settings.textBox, settings)
  box.current_string = ''
  windower.register_event('prerender', handleUIPrerender)
  windower.register_event('outgoing chunk', processOutgoingDataChunk)
  windower.register_event('incoming chunk', processIncomingDataChunk)

  if settings.visible then
    box:show()
  end
end

function handleUIPrerender()
  if (frameCount % 30 == 0) and box:visible() then
    updateUI()
  end

  frameCount = frameCount + 1
end

function processOutgoingDataChunk(id, data, modified, isInjected, isBlocked)
  if isInjected then
    return
  end

  local packetTable = packets.parse('outgoing', data)

  if id == 0x074 then
    if packetTable['Join'] and settings.resetOnPartyAccept then
      print('[BitsXP] Automatically clearing session XP...')
      clearUISession()
    end
  end

end

function processIncomingDataChunk(id, data, modified, isInjected, isBlocked)
  if isInjected then
    return
  end

  local packetTable = packets.parse('incoming', data)

  if id == 0x2D then
    if packetTable['Message'] == 8 or packetTable['Message'] == 253 then
      -- player gained experience points
      addExperiencePoints(packetTable['Param 1'])
    end
  elseif id == 0x61 then
    --UI.xp.current = packetTable['Current EXP']
    --UI.xp.max = packetTable['Required EXP']
	UI.xp.current = data:unpack('H',0x11)
	UI.xp.max = data:unpack('H',0x13)
    UI.xp.remaining = UI.xp.max - UI.xp.current
  elseif id == 0xB and box:visible() then
    box:hide()
  elseif id == 0xA and settings.visible then
    box:show()
  end
end

function updateUI()
  -- Lv. 24 NIN/WAR
  -- XP: 234 / 1,321
  -- TNL: 834
  -- XP/hr: 15.7k
  -- ETL: 1h26m30s
  -- [Next chain #3: 1m27s left]

  -- first, update xp rates
  updateXPRate()

  -- local info = windower.ffxi.get_player()
  local string = ' '..buildXPLabel()..white(' | ')
  string = string..buildTNLLabel()..white(' | ')
  string = string..buildXPPerHourLabel()..white(' | ')
  string = string..buildEstimatedTimeToLevelLabel()

  if sessionIsOnChain() then
    string = string..white(' | ') ..buildNextChainLabel()
  end

  box.current_string = string..' '
end

function buildJobLabel(info)
  local level = info.main_job_level
  local pJob = string.upper(info.main_job)
  local sJob = (info.sub_job and string.upper(info.sub_job))

  return white('Lv. '..level..' '..pJob..'/'..sJob)
end

function buildXPLabel()
  return white('XP: '..ice(commaValue(UI.xp.current)..'/'..commaValue(UI.xp.max)))
end

function buildTNLLabel()
  return white('TNL: '..ice(commaValue(UI.xp.remaining)))
end

function buildXPPerHourLabel()
  local xphr = UI.session.xpRatePerHour

  if xphr < 5 then
    xphr = red(xphr)
  elseif xphr >= 5 and xphr < 10 then
    xphr = yellow(xphr)
  elseif xphr >= 10 then
    xphr = green(xphr)
  end

  return white('XP/hr: '..xphr..'k')
end

function buildEstimatedTimeToLevelLabel()
  return white('ETL: '..ice(calculateTimeToLevel()))
end

function buildNextChainLabel()
  local nextChain = UI.session.nextChain

  return 'Next Chain #'..ice(nextChain.number)..white(' has ')..ice(calculateTimeLeftForNextChain())..white(' left')
end

function sessionIsOnChain()
  return UI.session.nextChain.number > 0
end

function calculateTimeToLevel()
  return formatTime(UI.session.estimatedTimeToLevelSeconds)
end

function calculateTimeLeftForNextChain()
  return '1m20s'
end

function addExperiencePoints(experienceGained)
  -- start the session if it's not started
  if UI.session.startTime == nil then
    UI.session.startTime = os.time()
    print('[BitsXP] Starting XP Session...')
  end

  -- add the exp to the session
  UI.session.xpEarned = UI.session.xpEarned + experienceGained

  -- also, add the exp to the character info
  UI.xp.current = UI.xp.current + experienceGained

  if UI.xp.current > UI.xp.remaining then
    UI.xp.current = UI.xp.current - UI.xp.remaining
  end
end

function updateXPRate()
  local startTime = UI.session.startTime
  if startTime == nil then
    startTime = os.time()
  end

  local timeElapsed = os.time() - startTime

  if timeElapsed == 0 or UI.session.xpEarned == 0 then
    return
  end

  UI.session.xpRatePerSecond = (UI.session.xpEarned / timeElapsed)
  UI.session.xpRatePerHour = round(UI.session.xpRatePerSecond * 3.6, 1)
  UI.session.estimatedTimeToLevelSeconds = math.floor(UI.xp.remaining / UI.session.xpRatePerSecond)

  -- update max xp
  UI.xp.max = (UI.xp.current + UI.xp.remaining)
end

function clearUISession()
  UI.session.startTime = nil
  UI.session.xpEarned = 0
  UI.session.xpRatePerSecond = 0
  UI.session.xpRatePerHour = 0
  UI.session.estimatedTimeToLevelSeconds = 0
  UI.session.nextChain = {
    number = 0,
    deadline = nil,
  }
end

function toggleUIVisibility()
  if settings.visible then
    settings.visible = false
    box:hide()
  else
    settings.visible = true
    box:show()
  end

  config.save(settings)
end
