local defaultOptions = {
    { "Alt", SOURCE, 1 },
    { "VSpeed", SOURCE, 1 },
    { "Reset", SOURCE, 1 },
    { "talk", BOOL, 1 },
    { "COLOR", COLOR, RED },
}

local launched_vspeed_trigger = 3
local flight_timer_id = 0

local lcd_unity_x_size = 30
local lcd_unity_x_small_size = 15
local alt_ref = 0
local alt_ref_delta = 0.5

local ImgBg = Bitmap.open("/WIDGETS/F3Klnch/img/bg.png")
-- local ImgPlane = Bitmap.open("img/plane.png")

local function check_flight_phase(current_mode, vspeed, alt)
    local mode = 'flight'
    local mode_compatible = {['launched'] = 'flight',
                            ['flight'] = 'landed',
                            ['landed'] = 'launched'}
    if alt < alt_ref_delta then
        mode = 'landed'
    end
    if current_mode == 'launched' then
        if vspeed < 0.1 then
            mode = 'flight'
        end
    end
    if vspeed >= launched_vspeed_trigger then
        mode = 'launched'
    end

    if mode_compatible[current_mode] ~= mode then
        mode = current_mode
    end

    local mode_changed = 0
    if mode ~= current_mode then
        mode_changed = 1
    end
    return mode_changed, mode
end

local function update_current_flight(current_flight, new_VSpeed, new_Alt)
    local mode_changed, new_mode = check_flight_phase(current_flight['mode'], new_VSpeed, new_Alt)

    if current_flight['mode'] == 'landed' and new_mode == 'launched' then
        current_flight = {['mode'] = new_mode,
                            ['launch_alt'] = 0,
                            ['flight_alt'] = 0,
                            ['launch_vspeed'] = 0,
                            ['flight_time'] = 0,
                        }
    end
    if new_mode == 'launched' then
        if new_Alt > current_flight['launch_alt'] then
            current_flight['launch_alt'] = new_Alt
        end
        if new_VSpeed > current_flight['launch_vspeed'] then
            current_flight['launch_vspeed'] = new_VSpeed
        end
    end
    current_flight['mode'] = new_mode
    current_flight['flight_alt'] = current_flight['flight_alt'] or 0
    if new_Alt > current_flight['flight_alt'] then
        current_flight['flight_alt'] = new_Alt
    end
    return mode_changed, current_flight
end

local function update_fligh_stat(launch_stat, current_flight, new_VSpeed, new_Alt)
    local mode_changed, updated_current_flight = update_current_flight(current_flight, new_VSpeed, new_Alt)

    if mode_changed == 1 and updated_current_flight['mode'] == 'flight' then
        playNumber(updated_current_flight['launch_alt'], 9, 0)
        local flight_timer = model.getTimer(flight_timer_id)
        -- reset flight timer
        flight_timer.value = flight_timer.start
		model.setTimer( flight_timer_id, flight_timer )
        model.resetTimer( flight_timer_id )
        -- start flight timer
        flight_timer.mode = 1
        model.setTimer(flight_timer_id, flight_timer)
    end
    if mode_changed == 1 and updated_current_flight['mode'] == 'landed' then
        -- Stop flight timer
        local flight_timer = model.getTimer(flight_timer_id)
        local flight_time = model.getTimer(flight_timer_id).value
        playDuration(flight_time)
        updated_current_flight['flight_time'] = flight_time

        flight_timer.mode = 0
		model.setTimer(flight_timer_id, flight_timer)


        -- update stat
        launch_stat['nbr_launch'] = launch_stat['nbr_launch'] + 1
        launch_stat['total_launch_alt'] = launch_stat['total_launch_alt'] + updated_current_flight['launch_alt']
        launch_stat['avg_launch_alt'] = launch_stat['total_launch_alt'] / launch_stat['nbr_launch']
        launch_stat['total_flight_alt'] = launch_stat['total_flight_alt'] + updated_current_flight['flight_alt']
        launch_stat['avg_flight_alt'] = launch_stat['total_flight_alt'] / launch_stat['nbr_launch']
        launch_stat['total_launch_vspeed'] = launch_stat['total_launch_vspeed'] + updated_current_flight['launch_vspeed']
        launch_stat['avg_launch_vspeed'] = launch_stat['total_launch_vspeed'] / launch_stat['nbr_launch']
        if launch_stat['max_launch_alt'] < updated_current_flight['launch_alt'] then
            launch_stat['max_launch_alt'] = updated_current_flight['launch_alt']
        end
        if launch_stat['max_launch_alt'] < updated_current_flight['launch_alt'] then
            launch_stat['max_launch_alt'] = updated_current_flight['launch_alt']
        end
        if launch_stat['max_flight_alt'] < updated_current_flight['flight_alt'] then
            launch_stat['max_flight_alt'] = updated_current_flight['flight_alt']
        end
        if launch_stat['max_launch_vspeed'] < updated_current_flight['launch_vspeed'] then
            launch_stat['max_launch_vspeed'] = updated_current_flight['launch_vspeed']
        end
        if launch_stat['max_flight_time'] < updated_current_flight['flight_time'] then
            launch_stat['max_flight_time'] = updated_current_flight['flight_time']
        end
        -- launch_stat['histo_flight'] = table.insert(launch_stat['histo_flight'], current_flight)
        -- Use modulo to turn on the 3 first position
        launch_stat['histo_flight'][((launch_stat['nbr_launch']-1)%3)+1] = current_flight
    end

    return launch_stat, updated_current_flight
end

local function read_telemetry(widget)
    local new_Alt = getValue(widget.options.Alt) - alt_ref
    local new_VSpeed = getValue(widget.options.VSpeed)

    return new_VSpeed, new_Alt
end

local function init_data()
    local launch_stat = {['nbr_launch'] = 0,
                            ['max_launch_alt'] = 0,
                            ['avg_launch_alt'] = 0,
                            ['total_launch_alt'] = 0,
                            ['max_flight_alt'] = 0,
                            ['avg_flight_alt'] = 0,
                            ['total_flight_alt'] = 0,
                            ['max_launch_vspeed'] = 0,
                            ['avg_launch_vspeed'] = 0,
                            ['total_launch_vspeed'] = 0,
                            ['max_flight_time'] = 0,
                            ['histo_flight'] = {},
                        }
    local current_flight = {['mode'] = 'landed',
                            ['launch_alt'] = 0,
                            ['launch_vspeed'] = 0,
                            ['flight_time'] = 0,
                            ['flight_alt'] = 0,
                            }
    -- Stop flight timer
    local flight_timer = model.getTimer(flight_timer_id)
    local flight_time = model.getTimer(flight_timer_id).value
    -- reset flight timer
    flight_timer.mode = 0
    model.setTimer(flight_timer_id, flight_timer)

    return launch_stat, current_flight
end
local function createWidget(zone, options)
    launch_stat, current_flight = init_data()
    return { zone=zone, options=options ,
            launch_stat = launch_stat, current_flight = current_flight }
end

local function updateWidget(widget, newOptions)
    widget.options = newOptions
end

local function backgroundProcessWidget(widget)
    local newVSpeed, newAlt = read_telemetry(widget)
    local launch_stat, updated_current_flight = update_fligh_stat(widget.launch_stat, widget.current_flight, newVSpeed, newAlt)

    widget.current_flight = updated_current_flight
    widget.launch_stat = launch_stat
end

local function draw_number(x, y, number, unity, precision, flags, unity_x_size)
    unity_x_size = unity_x_size or lcd_unity_x_size
    lcd.drawText(x, y, unity, flags)
    if precision ~= nil then
        lcd.drawNumber(x-unity_x_size, y, number*100, precision + flags)
    else
        lcd.drawNumber(x-unity_x_size, y, number, flags)
    end
end

local function refreshWidget(widget)
    local reset_switch = getValue(widget.options.Reset)
    if reset_switch > 0 then
        alt_ref = getValue(widget.options.Alt)
        widget.launch_stat, widget.current_flight = init_data()
        return
    end

    local newVSpeed, newAlt = read_telemetry(widget)
    local launch_stat, updated_current_flight = update_fligh_stat(widget.launch_stat, widget.current_flight, newVSpeed, newAlt)

    widget.current_flight = updated_current_flight
    widget.launch_stat = launch_stat

    local value_x_align = 140
    local inter_line = 20
    local y_line = widget.zone.y

    local function next_line(y_line, inter_line)
        return y_line + inter_line
    end

    -- local width, height = Bitmap.getSize(ImgBg)
    -- lcd.drawText(widget.zone.x + 5, y_line, "width :")
    -- lcd.drawNumber(widget.zone.x + value_x_align, y_line,
    --                 width,
    --                 RIGHT + TEXT_COLOR + SHADOWED)
    -- y_line = next_line(y_line, inter_line)
    -- lcd.drawText(widget.zone.x + 5, y_line, "height :")
    -- lcd.drawNumber(widget.zone.x + value_x_align, y_line,
    -- height,
    -- RIGHT + TEXT_COLOR + SHADOWED)

    -- y_line= next_line(y_line, inter_line)

    -- lcd.drawText(widget.zone.x + 5, y_line, "width :")
    -- lcd.drawNumber(widget.zone.x + value_x_align, y_line,
    --                 widget.zone.w,
    --                 RIGHT + TEXT_COLOR + SHADOWED)
    -- y_line = next_line(y_line, inter_line)
    -- lcd.drawText(widget.zone.x + 5, y_line, "height :")
    -- lcd.drawNumber(widget.zone.x + value_x_align, y_line,
    -- widget.zone.h,
    -- RIGHT + TEXT_COLOR + SHADOWED)

    -- y_line= next_line(y_line, inter_line)


    -- lcd.clear()
    lcd.drawBitmap(ImgBg, widget.zone.x, widget.zone.y)
    -- lcd.drawLine(widget.zone.x + 60, widget.zone.y + 60, widget.zone.x + 160, widget.zone.y + 160, SOLID, CUSTOM_COLOR)
    -- lcd.drawBitmap(ImgBg, widget.zone.x + 4, widget.zone.y + 4)
    -- lcd.drawFilledRectangle(widget.zone.x + 4, widget.zone.y + 4, 60, 60, CUSTOM_COLOR)
    -- lcd.drawText(widget.zone.x + 5, y_line, "Nbr launched :")
    -- lcd.drawNumber(widget.zone.x + value_x_align, y_line,
    --                 widget.launch_stat['nbr_launch'],
    --                 RIGHT + TEXT_COLOR + SHADOWED)
    -- y_line = next_line(y_line, inter_line)
    -- lcd.drawText(widget.zone.x + 5, y_line, "Mode :")
    -- lcd.drawText(widget.zone.x + value_x_align, y_line, widget.current_flight['mode']);
    -- y_line= next_line(y_line, inter_line)

    lcd.drawText(widget.zone.x + 140 - lcd_unity_x_size, widget.zone.y + 40,
                widget.current_flight['mode'],
                RIGHT + TEXT_COLOR + SHADOWED)
    draw_number(widget.zone.x + 140, widget.zone.y + 65,
                widget.current_flight['launch_alt'], 'm',
                PREC2, RIGHT + TEXT_COLOR + SHADOWED)
    draw_number(widget.zone.x + 140, widget.zone.y + 90,
                widget.current_flight['launch_vspeed'], 'ms',
                PREC2, RIGHT + TEXT_COLOR + SHADOWED)
    draw_number(widget.zone.x + 140, widget.zone.y + 115,
                widget.current_flight['flight_alt'], 'm',
                -- getValue(widget.options.Reset), 'm',
                PREC2, RIGHT + TEXT_COLOR + SHADOWED)
    lcd.drawTimer(widget.zone.x + 140 - lcd_unity_x_size, widget.zone.y + 140,
                    model.getTimer(flight_timer_id).value,
                    TIMEHOUR + RIGHT + TEXT_COLOR + SHADOWED)

    local histo_y = 25
    for i, flight in ipairs(widget.launch_stat['histo_flight']) do
        if i > widget.launch_stat['nbr_launch'] or i > 3 then
            break
        end
        draw_number(widget.zone.x + 265, widget.zone.y + histo_y,
                    flight['launch_alt'], 'm',
                    PREC2, RIGHT + TEXT_COLOR + SMLSIZE, lcd_unity_x_small_size)
        draw_number(widget.zone.x + 325, widget.zone.y + histo_y,
                    flight['launch_vspeed'], 'ms',
                    PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
        lcd.drawTimer(widget.zone.x + 388, widget.zone.y + histo_y,
                    flight['flight_time'],
                    TIMEHOUR + RIGHT + TEXT_COLOR + SMLSIZE)
        histo_y = histo_y + 15
    end

    -- Print launch Alt
    draw_number(widget.zone.x + 325, widget.zone.y + 95,
                widget.launch_stat['avg_launch_alt'], 'm',
                PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
    draw_number(widget.zone.x + 388, widget.zone.y + 95,
                widget.launch_stat['max_launch_alt'], 'm',
                PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
    -- Print flight Alt
    draw_number(widget.zone.x + 325, widget.zone.y + 110,
                widget.launch_stat['avg_flight_alt'], 'm',
                PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
    draw_number(widget.zone.x + 388, widget.zone.y + 110,
                widget.launch_stat['max_flight_alt'], 'm',
                PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
    -- Print launch vspeed
    draw_number(widget.zone.x + 325, widget.zone.y + 125,
                widget.launch_stat['avg_launch_vspeed'], 'ms',
                PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
    draw_number(widget.zone.x + 388, widget.zone.y + 125,
                widget.launch_stat['max_launch_vspeed'], 'ms',
                PREC2, RIGHT + TEXT_COLOR + SMLSIZE, 20)
    lcd.drawTimer(widget.zone.x + 388, widget.zone.y + 140,
                widget.launch_stat['max_flight_time'],
                TIMEHOUR + RIGHT + TEXT_COLOR + SMLSIZE)

end

return { name="F3Klnch", options=defaultOptions, create=createWidget, update=updateWidget
        , refresh=refreshWidget, background=backgroundProcessWidget }