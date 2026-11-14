-- English: the base language. Every key lives here; other languages may leave keys out.
local _, ns = ...

ns.RegisterLocale("enUS", {
    -- Main button
    TOOLTIP_MAIN_LEFT = "Left-click: open the ring",
    TOOLTIP_MAIN_RIGHT = "Right-click: settings",
    TOOLTIP_MAIN_DRAG = "Drag: move the button",
    TOOLTIP_MAIN_LOCKED = "The button is locked in place.",

    -- Ring
    TOOLTIP_SLOT_LEFT = "Left-click: a random line",
    TOOLTIP_SLOT_RIGHT = "Right-click: choose a line",
    TOOLTIP_EMPTY = "No lines yet. Add some in the settings.",
    TOOLTIP_MORE = "... and %d more",

    -- Minimap button
    TOOLTIP_MINIMAP_LEFT = "Click: settings",
    TOOLTIP_MINIMAP_DRAG = "Drag: move around the minimap",

    -- Chat messages
    MSG_NO_CATEGORIES = "You have no categories yet. Add one in the settings.",
    MSG_CATEGORY_EMPTY = "\"%s\" has no lines that can be posted yet.",
    MSG_POSITION_RESET = "The button is back in the middle of the screen.",
    MSG_DISCARDED = "A line with errors was not saved; your changes to it were discarded.",
    MSG_MAX_CATEGORIES = "The ring holds at most %d categories.",
    MSG_BLOCKED = "The game blocked an action of this addon (%s). Please report it.",
    MSG_HELP = "/rpqr - settings, /rpqr reset - move the button back to the middle of the screen",

    -- Settings window
    CONFIG_TITLE = "RP - Quick Response",
    CONFIG_CATEGORIES = "Categories",
    CONFIG_ENTRIES = "Lines",
    CONFIG_NAME = "Name",
    CONFIG_ICON = "Icon",
    CONFIG_SHORT = "Short (shown in the ring)",
    CONFIG_FULL = "Full (run like a macro)",
    CONFIG_HINT = "One command per line, as in a macro: /s, /e, /y, emotes like /wave or /bow, or any other command. A line without a command is said.",
    CONFIG_NO_ENTRY = "Choose a line on the left, or add a new one.",
    CONFIG_SAVED = "Saved.",

    BTN_NEW = "New",
    BTN_DELETE = "Delete",
    BTN_UP = "Up",
    BTN_DOWN = "Down",
    BTN_NEW_ENTRY = "New line",
    BTN_SAVE = "Save",
    BTN_REVERT = "Revert",
    BTN_TEST = "Post now",
    BTN_RESET_POSITION = "Reset position",
    TOOLTIP_ICON_CHOOSE = "Click to choose an icon",
    CHECK_LOCK = "Lock button",
    CHECK_MINIMAP = "Minimap button",

    NEW_CATEGORY = "New category",
    NEW_ENTRY = "New line",
    CONFIRM_DELETE_CATEGORY = "Delete the category \"%s\" and all of its lines?",

    -- Profiles
    CONFIG_PROFILE = "Profile",
    TOOLTIP_PROFILE = "Use this character's own lines, or a profile shared with your other characters. Changes go to whatever is in use.",
    PROFILE_OWN = "Own lines (%s)",
    PROFILE_DEFAULT_NAME = "Profile",
    BTN_NEW_PROFILE = "New profile",
    BTN_DELETE_PROFILE = "Delete profile",
    CONFIRM_NEW_PROFILE = "Name of the new profile. It starts with a copy of the lines in use now.",
    CONFIRM_DELETE_PROFILE = "Delete the profile \"%s\"? Characters using it go back to their own lines.",
    MSG_PROFILE_CREATED = "Profile \"%s\" created; this character uses it now.",
    ERR_PROFILE_NO_NAME = "A profile needs a name.",
    ERR_PROFILE_TOO_LONG = "A profile name holds at most %d characters.",
    ERR_PROFILE_EXISTS = "A profile named \"%s\" already exists.",

    -- Icon browser
    ICON_BROWSER_TITLE = "Choose an icon",
    ICON_SEARCH = "Name or file ID",
    ICON_COUNT = "%d icons",
    ICON_NONE = "No icon matches.",
    ICON_UNNAMED = "Unnamed icon",
    ICON_FILE_ID = "File ID: %d",

    -- Checks on Full
    ERR_NO_COMMAND = "Line %d: a command is missing after the /.",
    ERR_LINE_TOO_LONG = "Line %d is longer than %d characters.",
    ERR_EMPTY_LINE = "Line %d: the command has no text.",
    ERR_NO_TEXT = "Full needs at least one line of text.",
    ERR_NO_SHORT = "Short must not be empty.",

    -- Example categories (created once, on first start, in the player's language)
    DEFAULT_GREETING = "Greeting",
    DEFAULT_GREETING_1_SHORT = "Wave",
    DEFAULT_GREETING_1_FULL = "/e waves warmly.",
    DEFAULT_GREETING_2_SHORT = "Well met",
    DEFAULT_GREETING_2_FULL = "/s Well met, traveller!",
    DEFAULT_GREETING_3_SHORT = "Bow",
    DEFAULT_GREETING_3_FULL = "/e bows politely.\n/s Welcome. May your road be a safe one.",

    DEFAULT_FAREWELL = "Farewell",
    DEFAULT_FAREWELL_1_SHORT = "Safe travels",
    DEFAULT_FAREWELL_1_FULL = "/s Safe travels, friend.",
    DEFAULT_FAREWELL_2_SHORT = "Nod and go",
    DEFAULT_FAREWELL_2_FULL = "/e nods and turns to leave.",
    DEFAULT_FAREWELL_3_SHORT = "Until next time",
    DEFAULT_FAREWELL_3_FULL = "/s Until next time!\n/e raises a hand in farewell.",

    DEFAULT_SURPRISE = "Surprise",
    DEFAULT_SURPRISE_1_SHORT = "What?!",
    DEFAULT_SURPRISE_1_FULL = "/s What in the world?!",
    DEFAULT_SURPRISE_2_SHORT = "Startled",
    DEFAULT_SURPRISE_2_FULL = "/e flinches, eyes wide.",
    DEFAULT_SURPRISE_3_SHORT = "Gasp",
    DEFAULT_SURPRISE_3_FULL = "/e gasps.\n/s By all that's holy...",

    DEFAULT_CURSING = "Cursing",
    DEFAULT_CURSING_1_SHORT = "Blast!",
    DEFAULT_CURSING_1_FULL = "/s Blast it all!",
    DEFAULT_CURSING_2_SHORT = "Mutter",
    DEFAULT_CURSING_2_FULL = "/e mutters a curse under their breath.",
    DEFAULT_CURSING_3_SHORT = "Fury",
    DEFAULT_CURSING_3_FULL = "/e stamps a foot.\n/s Curse this wretched luck!",
})
