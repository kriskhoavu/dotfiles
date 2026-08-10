-- Window pairing powered by Hammerspoon + Rectangle.
-- Rectangle owns placement; Hammerspoon supplies the searchable second-window picker.

local pairingModifiers = { "ctrl", "alt", "shift" }
local windowSwitcherModifiers = { "ctrl", "alt", "cmd" }

local function rectangleMove(direction)
  hs.urlevent.openURL("rectangle://execute-action?name=" .. direction .. "-half")
end

local function appIcon(app)
  local bundleID = app:bundleID()
  return bundleID and hs.image.imageFromAppBundle(bundleID) or nil
end

local function selectableWindows(sourceWindow)
  local choices = {}

  for _, window in ipairs(hs.window.allWindows()) do
    local app = window:application()
    if window:id() ~= sourceWindow:id()
      and app ~= nil
      and window:isStandard()
      and not window:isMinimized() then
      local title = window:title()
      table.insert(choices, {
        text = app:name(),
        subText = title ~= "" and title or "Untitled window",
        image = appIcon(app),
        window = window,
      })
    end
  end

  table.sort(choices, function(a, b)
    return (a.text .. a.subText):lower() < (b.text .. b.subText):lower()
  end)
  return choices
end

local function showWindowSwitcher()
  local choices = {}

  for _, window in ipairs(hs.window.allWindows()) do
    local app = window:application()
    if app ~= nil and window:isStandard() and not window:isMinimized() then
      local title = window:title()
      table.insert(choices, {
        text = app:name(),
        subText = title ~= "" and title or "Untitled window",
        image = appIcon(app),
        window = window,
      })
    end
  end

  table.sort(choices, function(a, b)
    return (a.text .. a.subText):lower() < (b.text .. b.subText):lower()
  end)

  hs.chooser.new(function(choice)
    if choice ~= nil and choice.window ~= nil then
      choice.window:focus()
    end
  end)
    :choices(choices)
    :placeholderText("Search an open app or window")
    :rows(12)
    :width(32)
    :show()
end

local function pairFocusedWindow(sourceSide, targetSide)
  local sourceWindow = hs.window.focusedWindow()
  if sourceWindow == nil then
    hs.alert.show("No focused window to pair")
    return
  end

  local choices = selectableWindows(sourceWindow)
  if #choices == 0 then
    hs.alert.show("No other open windows to pair")
    return
  end

  -- Move the original window first through Rectangle's direct command URL.
  rectangleMove(sourceSide)

  hs.timer.doAfter(0.15, function()
    hs.chooser.new(function(choice)
      if choice == nil or choice.window == nil then
        return
      end
      if not choice.window:focus() then
        hs.alert.show("That window is no longer available")
        return
      end

      -- Rectangle places the selected window on the opposite half.
      hs.timer.doAfter(0.10, function()
        rectangleMove(targetSide)
      end)
    end)
      :choices(choices)
      :placeholderText("Search an open window to pair")
      :rows(12)
      :width(32)
      :show()
  end)
end

-- Ctrl-Option-Shift-Left: current window left, selected window right.
hs.hotkey.bind(pairingModifiers, "left", function()
  pairFocusedWindow("left", "right")
end)

-- Ctrl-Option-Shift-Right: current window right, selected window left.
hs.hotkey.bind(pairingModifiers, "right", function()
  pairFocusedWindow("right", "left")
end)

-- Ctrl-Option-Command-Down: searchable replacement for app/window switching.
hs.hotkey.bind(windowSwitcherModifiers, "down", showWindowSwitcher)
