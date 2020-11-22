options={'launched_vspeed_trigger': 5}

def check_flight_phase(current_mode, vspeed, alt):
    mode = 'landed'
    mode_compatible = {'launched': 'flight', 
                        'flight': 'landed',
                        'landed': 'launched'}

    if alt > 0.1 and vspeed < options['launched_vspeed_trigger']:
        mode = 'flight'

    if vspeed > options['launched_vspeed_trigger']:
        mode = 'launched'
    if mode_compatible[current_mode] != mode:
        mode = current_mode

    return mode

def test_check_lauch():
    # check launched mode alt 0 current = launched
    assert check_flight_phase('launched', 7, 0) == 'launched'
    # check launched mode alt > 0
    assert check_flight_phase('launched', 7, 5) == 'launched'
    # check launched mode alt > 0 current = flight
    assert check_flight_phase('flight', 7, 5) == 'flight'

def test_check_landed():
    # check launched mode
    assert check_flight_phase('flight', 2, 0) == 'landed'
    # check landed mode
    assert check_flight_phase('flight', 0, 0) == 'landed'
    # check launched mode
    assert check_flight_phase('launched', 0, 0) == 'launched'

def test_check_flight():
    # check launched mode
    assert check_flight_phase('launched', 0, 0.3) == 'flight'
    # check landed mode
    assert check_flight_phase('launched', 4, 5) == 'flight'