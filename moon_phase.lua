--[==[
    M O O N   P H A S E   W I D G E T   —   moon_phase.lua
    ---------------------------------------------------------------
    Standalone extract of the moon phase widget from sci-fi.lua and batcomputer.lua
    (the Batcomputer/ArkhamOS conky HUD). Draws just the moon icon,
    its phase name, and % illumination, nothing else.

    USAGE:
      In your conky.conf (conky >= 1.10, needs `lua_load` and Cairo):

        conky.config = {
            lua_load = '~/.config/conky/moon_phase.lua',
            lua_draw_hook_post = 'conky_moon_post',
            own_window_argb_visual = true,
            own_window_transparent = false,
            own_window_argb_value = 0,
            update_interval = 60,   -- moon phase barely changes; no
                                    -- need to redraw every second
        }
        conky.text = empty string, everything is drawn via Cairo

      Adjust CFG below (position, size, colors) to taste.
--]==]

require 'cairo'

-- =====================================================================
--  CONFIG
-- =====================================================================
local CFG = {
    -- Position/size of the widget inside the conky window
    X = 40,
    Y = 40,
    RADIUS = 24,

    -- Set true if you're south of the equator (flips waxing/waning
    -- illumination side to match what you actually see in the sky)
    MOON_SOUTHERN_HEMISPHERE = false,

    COL_PRIMARY     = '#3fd6ff',
    COL_PRIMARY_DIM = '#1a6b85',
    COL_TEXT_DIM    = '#4fb8d6',
    COL_MOON_DARK   = '#081a20',

    FONT_MAIN = 'Share Tech Mono',
}

-- =====================================================================
--  UTILITIES
-- =====================================================================
local function hex2rgb(hex)
    hex = hex:gsub('#', '')
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function set_rgba(cr, hex, a)
    local r, g, b = hex2rgb(hex)
    cairo_set_source_rgba(cr, r, g, b, a or 1)
end

local function text_width(cr, str)
    local ext = cairo_text_extents_t:create()
    cairo_text_extents(cr, str, ext)
    return ext.width, ext.height
end

local function draw_text(cr, x, y, str, size, hex, alpha, align, face, weight)
    cairo_select_font_face(cr, face or CFG.FONT_MAIN, CAIRO_FONT_SLANT_NORMAL, weight or CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, size)
    set_rgba(cr, hex, alpha)
    local dx = 0
    if align and align ~= 'left' then
        local w = text_width(cr, str)
        dx = (align == 'center') and -w / 2 or -w
    end
    cairo_move_to(cr, x + dx, y)
    cairo_show_text(cr, str)
end

-- =====================================================================
--  MOON PHASE MATH
-- =====================================================================
local SYNODIC_MONTH = 29.530588853
local KNOWN_NEW_MOON_JD = 2451549.5

local MOON_NAMES = {
    'New Moon', 'Waxing Crescent', 'First Quarter', 'Waxing Gibbous',
    'Full Moon', 'Waning Gibbous', 'Last Quarter', 'Waning Crescent',
}

local function moon_phase_fraction()
    local jd = os.time() / 86400 + 2440587.5
    local phase = ((jd - KNOWN_NEW_MOON_JD) / SYNODIC_MONTH) % 1
    if phase < 0 then phase = phase + 1 end
    return phase
end

local function moon_phase_name(phase)
    local idx = math.floor(phase * 8 + 0.5) % 8
    return MOON_NAMES[idx + 1]
end

local function draw_moon(cr, cx, cy, r, phase)
    cairo_new_path(cr)
    cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
    set_rgba(cr, CFG.COL_MOON_DARK, 1)
    cairo_fill(cr)

    local gamma = -math.cos(phase * 2 * math.pi)
    local waxing = phase < 0.5
    if CFG.MOON_SOUTHERN_HEMISPHERE then waxing = not waxing end

    cairo_save(cr)
    cairo_new_path(cr)
    if waxing then
        cairo_arc(cr, cx, cy, r, -math.pi / 2, math.pi / 2)
    else
        cairo_arc(cr, cx, cy, r, math.pi / 2, 3 * math.pi / 2)
    end
    cairo_translate(cr, cx, cy)
    cairo_scale(cr, gamma, 1)
    cairo_translate(cr, -cx, -cy)
    if waxing then
        cairo_arc(cr, cx, cy, r, math.pi / 2, 3 * math.pi / 2)
    else
        cairo_arc(cr, cx, cy, r, -math.pi / 2, math.pi / 2)
    end
    cairo_close_path(cr)
    set_rgba(cr, CFG.COL_PRIMARY, 1)
    cairo_fill(cr)
    cairo_restore(cr)

    cairo_new_path(cr)
    cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
    set_rgba(cr, CFG.COL_PRIMARY_DIM, 0.6)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)
end

-- =====================================================================
--  MAIN DRAW HOOK
-- =====================================================================
function conky_moon_post()
    if conky_window == nil then return end

    local W, H = conky_window.width, conky_window.height
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, W, H)
    local cr = cairo_create(cs)

    cairo_save(cr)
    cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR)
    cairo_paint(cr)
    cairo_restore(cr)

    local phase = moon_phase_fraction()
    local illum = (1 - math.cos(phase * 2 * math.pi)) / 2 * 100

    local cx, cy, r = CFG.X + CFG.RADIUS, CFG.Y + CFG.RADIUS, CFG.RADIUS
    draw_moon(cr, cx, cy, r, phase)
    draw_text(cr, cx + r + 14, CFG.Y + 12, moon_phase_name(phase), 11, CFG.COL_PRIMARY, 1, 'left', CFG.FONT_MAIN, CAIRO_FONT_WEIGHT_BOLD)
    draw_text(cr, cx + r + 14, CFG.Y + 30, string.format('%d%% ILLUMINATED', math.floor(illum + 0.5)), 9, CFG.COL_TEXT_DIM, 0.85)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
