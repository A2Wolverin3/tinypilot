import dataclasses


class Error(Exception):
    pass


class MissingFieldErrorError(Error):
    pass


class InvalidButtonStateError(Error):
    pass


class InvalidRelativePositionError(Error):
    pass


class InvalidRelativeMovementError(Error):
    pass


class InvalidWheelValueError(Error):
    pass


# JavaScript only supports 5 mouse buttons.
# https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/buttons
_MAX_BUTTONS = 5
_MAX_BUTTON_STATE = pow(2, _MAX_BUTTONS) - 1


@dataclasses.dataclass
class MouseEvent:
    # A flag indicating whether the event is for an absolute or relative mouse.
    is_relative: bool

    # A bitmask of buttons pressed during the mouse event.
    buttons: int

    # Absolute Events: A value from 0.0 to 1.0 representing the cursor's
    #   relative position on the screen.
    # Relative Events: A value from -32767 to 32767 representing the cursor's
    #   movement from it's previous position.
    relative_x: int
    relative_y: int

    # Wheel deltas can either be:
    # -1 - Scroll up.
    #  0 - Don't change scroll position.
    #  1 - Scroll down.
    vertical_wheel_delta: int
    horizontal_wheel_delta: int


def parse_mouse_event(message):
    if not isinstance(message, dict):
        raise MissingFieldErrorError(
            'Mouse event parameter is invalid, expecting a dictionary data type'
        )
    required_fields = ('isRelative', 'buttons', 'relativeX', 'relativeY',
                       'verticalWheelDelta', 'horizontalWheelDelta')
    for field in required_fields:
        if field not in message:
            raise MissingFieldErrorError(
                f'Mouse event request is missing required field: {field}')
    is_rel = bool(message['isRelative'])
    if is_rel:
        relx = _parse_relative_move(message['relativeX'])
        rely = _parse_relative_move(message['relativeY'])
    else:
        relx = _parse_relative_position(message['relativeX'])
        rely = _parse_relative_position(message['relativeY'])
    return MouseEvent(
        is_relative=is_rel,
        buttons=_parse_button_state(message['buttons']),
        relative_x=relx,
        relative_y=rely,
        vertical_wheel_delta=_parse_wheel_value(message['verticalWheelDelta']),
        horizontal_wheel_delta=_parse_wheel_value(
            message['horizontalWheelDelta']),
    )


def _parse_button_state(buttons):
    if not isinstance(buttons, int):
        raise InvalidButtonStateError(
            f'Button state must be an integer value: {buttons}')
    if not (0 <= buttons <= _MAX_BUTTON_STATE):
        raise InvalidButtonStateError(
            f'Button state must be <= {_MAX_BUTTON_STATE:#x}: {buttons}')
    return buttons


def _parse_relative_position(relative_position):
    if not isinstance(relative_position, float) and not isinstance(
            relative_position, int):
        raise InvalidRelativePositionError(
            'Relative position must be a float between 0.0 and 1.0: '
            f'{relative_position}')
    if not (0.0 <= relative_position <= 1.0):
        raise InvalidRelativePositionError(
            'Relative position must be a float between 0.0 and 1.0: '
            f'{relative_position}')
    return relative_position


def _parse_relative_move(relative_movement):
    if not isinstance(relative_movement, int):
        raise InvalidRelativeMovementError(
            'Relative movement must be an integer between +/-32767: '
            f'{relative_movement}')
    if not (-32767 <= relative_movement <= 32767):
        raise InvalidRelativeMovementError(
            'Relative movement must be an integer between +/-32767: '
            f'{relative_movement}')
    return relative_movement


def _parse_wheel_value(wheel_value):
    if not isinstance(wheel_value, int):
        raise InvalidWheelValueError(
            f'Wheel value must be a int: {wheel_value}')
    if wheel_value not in (-1, 0, 1):
        raise InvalidWheelValueError(
            f'Wheel value must be -1, 0, or 1: {wheel_value}')
    return wheel_value
