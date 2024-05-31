-- Checkpoints 1.0
-- by Hopper

-- Configuration

Checkpoints = {}
Checkpoints.enable = true -- use checkpoints (hides annotations either way)
Checkpoints.only_with_quicksave = true -- disable checkpoints that invoke UI
Checkpoints.marker_text = "CP" -- annotations with this text are checkpoints
Checkpoints.at_level_start = true -- save when a new level is entered

-- Required triggers
-- If you integrate checkpoints with your own Lua,
-- be sure to call Checkpoint.init() and Checkpoint.idle(),
-- and call Game.restore_saved() when appropriate.

Triggers = {}
function Triggers.init(restoring_game)
  if restoring_game then Game.restore_saved() end
  Checkpoints.init(restoring_game)
end
function Triggers.idle()
  Checkpoints.idle()
end


-- begin Checkpoints code; do not modify beyond this point
-- unless you know what you're doing ;)

-- internal variables
Checkpoints.enabled = false
Checkpoints.delayed_checkpoint = nil
Checkpoints.level_transition = false

-- init trigger: detect checkpoints and set custom fields
function Checkpoints.init(restoring_game)
  
  if (not Checkpoints.only_with_quicksave) or Game.version >= "20150619" then
    Checkpoints.enabled = true
  end
  if (not Checkpoints.enable) or #Players > 1 or Game.version < "20090909" then
    Checkpoints.enabled = false
  end
  
  if restoring_game then return end
  
  -- find and mark checkpoints
  for a in Annotations() do
    if a.polygon ~= nil and a.text == Checkpoints.marker_text then
      -- make sure checkpoint annotation isn't visible on map
      a.x = 100000
      a.y = 100000
      if Checkpoints.enabled then
        a.polygon._checkpoint = 0 - a.polygon.index
      end
    end
  end
    
  -- coalesce adjacent checkpoints
  for p in Polygons() do
    if p._checkpoint ~= nil and p._checkpoint < 0 then
      p._checkpoint = p.index
      Checkpoints.mark_adjacent(p, p.index)
    end
  end
  
  -- request new-level checkpoint
  if Checkpoints.at_level_start and Game.ticks > 0 then
    Checkpoints.level_transition = true
  end
end

function Checkpoints.mark_adjacent(start, marker)
  for p in start.adjacent_polygons() do
    if p._checkpoint ~= nil and p._checkpoint < 0 then
      p._checkpoint = marker
      Checkpoints.mark_adjacent(p, marker)
    end
  end
end
  
-- idle trigger: fire delayed checkpoint or detect entering one
function Checkpoints.idle()
  if not Checkpoints.enabled then return end
  
  
  local cur_poly = Players[0].polygon
  local main_poly = nil
  if cur_poly._checkpoint then
    main_poly = Polygons[cur_poly._checkpoint]
    if not main_poly._checkpoint then
      -- the checkpoint for cur_poly has been deactivated
      cur_poly._checkpoint = nil
      main_poly = nil
    end
  end
  
  if Checkpoints.level_transition then
    if Game.version < "20150619" or cur_poly.visible_on_automap then
      Checkpoints.level_transition = false
      Game.save()
      if main_poly then
        cur_poly._checkpoint = nil
        main_poly._checkpoint = nil
      end
    end
  elseif Checkpoints.delayed_checkpoint then
    if Checkpoints.coast_is_clear() then
      -- if we're standing in a different checkpoint, cancel it too
      if main_poly then
        cur_poly._checkpoint = nil
        main_poly._checkpoint = nil
      end
      Checkpoints.delayed_checkpoint = nil
      Game.save()
    end
  elseif main_poly then
    cur_poly._checkpoint = nil
    main_poly._checkpoint = nil
    if Checkpoints.coast_is_clear() then
      Game.save()
    else
      Checkpoints.delayed_checkpoint = cur_poly.index
    end
  end
end

function Checkpoints.coast_is_clear()
  -- delay if there's weapons fire (TBD: limit to nearby)
  for p in Projectiles() do
    return false
  end
  
  -- delay if monsters are fighting player (not feasible with current API)
  
  -- delay for monsters nearby (in motion-sensor range)
  for m in Monsters() do
    if (not m.player) and m.active and m.action ~= "stationary" then
      local xdiff = m.x - Players[0].x
      local ydiff = m.y - Players[0].y
      local dist = math.sqrt(xdiff*xdiff + ydiff*ydiff)
      if dist <= 8 then return false end
    end
  end

  return true
end
