-- Window pairing powered by Hammerspoon + Rectangle.
-- Rectangle owns placement; Hammerspoon supplies the searchable second-window picker.

local pairingModifiers = { "ctrl", "alt", "shift" }
local windowSwitcherModifiers = { "cmd", "shift" }
local iconCache = {}
local pairTargetSide = nil
local pairRequest = 0

local function rectangleMove(direction)
  hs.urlevent.openURL("rectangle://execute-action?name=" .. direction .. "-half")
end

local function appIcon(app)
  local bundleID = app:bundleID()
  if bundleID == nil then
    return nil
  end

  -- Loading an app icon can hit LaunchServices/the disk. Keep that work out of
  -- every chooser refresh, especially on the first few invocations.
  if iconCache[bundleID] == nil then
    iconCache[bundleID] = hs.image.imageFromAppBundle(bundleID) or false
  end
  return iconCache[bundleID] or nil
end

local function isUserApp(app)
  -- `kind() == 1` means a regular Dock application. This excludes macOS UI
  -- agents such as Notification Center, whose AX windows are not useful here.
  return app ~= nil and app:kind() == 1
end

local function isSelectableWindow(window)
  -- `isStandard()` is unnecessarily strict here: some apps expose a maximized
  -- window with a non-standard accessibility subrole. The AXWindow role still
  -- filters out controls such as Chrome's companion status-bar window.
  return window:id() ~= nil
    and window:role() == "AXWindow"
    and not window:isMinimized()
end

-- One accessibility scan produces the full list; the pair picker derives its
-- own list from that snapshot instead of scanning a second time. Scanning is by
-- far the slowest part of opening a chooser, so the result is cached and reused
-- while the fresh scan runs in the background.
local cachedChoices = nil

local function collectChoices()
  local choices = {}
  local appsWithWindows = {}

  for _, window in ipairs(hs.window.allWindows()) do
    local app = window:application()
    if isUserApp(app) and isSelectableWindow(window) then
      local title = window:title()
      local bundleID = app:bundleID()
      if bundleID ~= nil then
        appsWithWindows[bundleID] = true
      end
      table.insert(choices, {
        text = app:name(),
        subText = title ~= "" and title or "Untitled window",
        image = appIcon(app),
        windowID = window:id(),
      })
    end
  end

  -- macOS does not always expose a true fullscreen window through the
  -- Accessibility API. Keep such running apps reachable in the switcher even
  -- when there is no window object to list.
  for _, app in ipairs(hs.application.runningApplications()) do
    local bundleID = app:bundleID()
    if isUserApp(app) and bundleID ~= nil and not appsWithWindows[bundleID] then
      table.insert(choices, {
        text = app:name(),
        subText = "Fullscreen or unavailable window",
        image = appIcon(app),
        appBundleID = bundleID,
      })
    end
  end

  table.sort(choices, function(a, b)
    return (a.text .. a.subText):lower() < (b.text .. b.subText):lower()
  end)

  cachedChoices = choices
  return choices
end

local function switcherChoices(choices)
  return choices
end

local function pairChoicesFor(sourceWindowID)
  return function(choices)
    local filtered = {}
    for _, choice in ipairs(choices) do
      if choice.windowID ~= sourceWindowID then
        if choice.appBundleID ~= nil then
          table.insert(filtered, {
            text = choice.text,
            subText = "Fullscreen — exit fullscreen before pairing",
            image = choice.image,
            appBundleID = choice.appBundleID,
          })
        else
          table.insert(filtered, choice)
        end
      end
    end
    return filtered
  end
end

local function usableWindow(windowID)
  local window = windowID and hs.window.get(windowID) or nil
  return window ~= nil and isSelectableWindow(window) and window or nil
end

local function appForChoice(choice)
  if choice == nil then
    return nil
  end

  if choice.appBundleID ~= nil then
    return hs.application.get(choice.appBundleID)
  end

  local window = choice.windowID and hs.window.get(choice.windowID) or nil
  return window and window:application() or nil
end

-- Reuse the native chooser views instead of constructing them in the hotkey
-- callbacks. This removes their first-use initialization from the interaction.
local windowSwitcher = hs.chooser.new(function(choice)
  local window = choice and usableWindow(choice.windowID) or nil
  if window ~= nil then
    window:focus()
  elseif choice ~= nil and choice.appBundleID ~= nil then
    local app = hs.application.get(choice.appBundleID)
    if app ~= nil then
      app:activate()
    else
      hs.alert.show("That app is no longer running")
    end
  elseif choice ~= nil then
    hs.alert.show("That window is no longer available")
  end
end)
  :placeholderText("Search an open app or window")
  :rows(12)
  :width(32)

local pairChooser = hs.chooser.new(function(choice)
  local targetSide = pairTargetSide
  pairTargetSide = nil
  if choice == nil then
    return
  end

  local window = usableWindow(choice.windowID)
  if window == nil and choice.appBundleID ~= nil then
    local app = hs.application.get(choice.appBundleID)
    if app ~= nil then
      app:activate()
      hs.alert.show("Exit fullscreen in " .. app:name() .. ", then pair it")
    else
      hs.alert.show("That app is no longer running")
    end
    return
  end

  if window == nil or not window:focus() then
    hs.alert.show("That window is no longer available")
    return
  end

  -- Let macOS finish moving focus before asking Rectangle to tile the window.
  hs.timer.doAfter(0.08, function()
    rectangleMove(targetSide)
  end)
end)
  :placeholderText("Search an open window to pair")
  :rows(12)
  :width(32)

-- Tracks how each visible chooser turns a window snapshot into its own rows, so
-- background refreshes can rebuild the right list.
local chooserTransform = {}

-- Show instantly from the last snapshot, then swap in a fresh one. The
-- accessibility scan can take a noticeable moment, and doing it before `show()`
-- is what made the dialog feel delayed.
local function showChooser(chooser, transform)
  chooserTransform[chooser] = transform

  -- Always start from a blank search rather than the previous invocation's.
  chooser:query("")
  chooser:choices(cachedChoices and transform(cachedChoices) or {})
  chooser:show()

  hs.timer.doAfter(0, function()
    if not chooser:isVisible() or chooserTransform[chooser] ~= transform then
      return
    end
    -- Keep whatever the user has already typed while the scan was running.
    local query = chooser:query()
    chooser:choices(transform(collectChoices()))
    chooser:query(query)
  end)
end

local function showWindowSwitcher()
  showChooser(windowSwitcher, switcherChoices)
end

local function refreshVisibleChooser(chooser, selectedRow)
  local transform = chooserTransform[chooser]
  if transform == nil then
    return
  end

  local query = chooser:query()
  chooser:choices(transform(collectChoices()))

  -- Preserve the user's search and keep selection near its prior row after a
  -- process disappears from the list.
  chooser:query(query)
  chooser:selectedRow(selectedRow)
end

local function forceQuitSelectedApp()
  local chooser = windowSwitcher:isVisible() and windowSwitcher
    or pairChooser:isVisible() and pairChooser
    or nil
  if chooser == nil then
    return
  end

  local selectedRow = chooser:selectedRow()
  local app = appForChoice(chooser:selectedRowContents())
  if app == nil then
    hs.alert.show("Select an app or window first")
    return
  end

  local appName = app:name()
  app:kill9()
  hs.alert.show("Force quit " .. appName, 0.7)
  hs.timer.doAfter(0.05, function()
    if chooser:isVisible() then
      refreshVisibleChooser(chooser, selectedRow)
    end
  end)
end

local function pairFocusedWindow(sourceSide, targetSide)
  local sourceWindow = hs.window.focusedWindow()
  if sourceWindow == nil then
    hs.alert.show("No focused window to pair")
    return
  end

  local sourceWindowID = sourceWindow:id()
  local transform = pairChoicesFor(sourceWindowID)
  if #transform(cachedChoices or collectChoices()) == 0 then
    hs.alert.show("No other open windows to pair")
    return
  end

  -- Move the original window first through Rectangle's direct command URL.
  rectangleMove(sourceSide)

  pairTargetSide = targetSide
  pairRequest = pairRequest + 1
  local request = pairRequest
  hs.timer.doAfter(0.08, function()
    -- Ignore a stale timer if the shortcut was pressed again during a transition.
    if request == pairRequest then
      showChooser(pairChooser, transform)
    end
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

-- Cmd-Shift-Space: searchable replacement for app/window switching.
hs.hotkey.bind(windowSwitcherModifiers, "space", showWindowSwitcher)

-- In either chooser, Delete force quits the highlighted app. Returning true
-- consumes Delete only while a chooser is visible, so arrow-key navigation and
-- normal Delete behavior elsewhere are unaffected.
local deleteKeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local deleteKey = event:getKeyCode() == 51 or event:getKeyCode() == 117
  if deleteKey and (windowSwitcher:isVisible() or pairChooser:isVisible()) then
    forceQuitSelectedApp()
    return true
  end
  return false
end)
deleteKeyWatcher:start()

-- Preload icons shortly after config load, while the user is not interacting.
-- This is deliberately deferred so a reload itself stays responsive.
hs.timer.doAfter(1, function()
  for _, app in ipairs(hs.application.runningApplications()) do
    appIcon(app)
  end
  collectChoices()
end)
