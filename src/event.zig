const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const ascii = std.ascii;

const Event = union(enum) { key: KeyEvent };

pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: KeyModifiers = KeyModifiers{},
};

pub const KeyCode = union(enum) {
    const Self = @This();

    backspace,
    enter,
    up,
    down,
    right,
    left,
    home,
    end,
    page_up,
    page_down,
    tab,
    back_tab,
    delete,
    insert,
    f: u8,
    char: u8,
    esc,
};

/// These modifiers map to the [Kitty Keyboard Protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/).
pub const KeyModifiers = packed struct {
    none: bool = true,
    shift: bool = false,
    alt: bool = false, // Option on mac
    control: bool = false,
    super: bool = false, // Window/Linux key or CMD on mac keyboards
    hyper: bool = false,
    meta: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,
};

fn lookup(input: []const u8) ?KeyEvent {
    if (input.len == 0) return null;
    const result = switch (input[0]) {
        // ESC
        '\x1b' => if (input.len >= 2) switch (input[1]) {
            // CSI
            '[' => switch (input[2]) {
                'A' => KeyEvent{ .code = KeyCode{ .up = {} } },
                'B' => KeyEvent{ .code = KeyCode{ .down = {} } },
                'C' => KeyEvent{ .code = KeyCode{ .right = {} } },
                'D' => KeyEvent{ .code = KeyCode{ .left = {} } },
                'H' => KeyEvent{ .code = KeyCode{ .home = {} } },
                'F' => KeyEvent{ .code = KeyCode{ .end = {} } },
                'Z' => KeyEvent{ .code = KeyCode{ .back_tab = {} }, .modifiers = KeyModifiers{ .shift = true } },
                '2' => if (input[3] == '~') KeyEvent{ .code = KeyCode{ .insert = {} } } else null,
                '5' => if (input[3] == '~') KeyEvent{ .code = KeyCode{ .page_up = {} } } else null,
                '6' => if (input[3] == '~') KeyEvent{ .code = KeyCode{ .page_down = {} } } else null,
                else => if (input.len == 2) KeyEvent{ .code = KeyCode{ .char = '[' } } else null,
            },
            // Ctrl
            0x01...0x1a, 0x1c...0x1f => KeyEvent{
                .code = KeyCode{ .char = input[1] + 96 },
                .modifiers = KeyModifiers{
                    .control = true,
                    .alt = true,
                },
            },
            // Alt
            else => if (input.len == 2) KeyEvent{
                .code = KeyCode{ .char = input[1] },
                .modifiers = KeyModifiers{
                    .alt = true,
                    .shift = ascii.isUpper(input[1]),
                },
            } else null,
            // Esc
        } else KeyEvent{ .code = KeyCode{ .esc = {} } },
        // Tab
        '\t' => KeyEvent{ .code = KeyCode{ .tab = {} } },
        // Delete
        '\x7f' => KeyEvent{ .code = KeyCode{ .delete = {} } },
        // Ctrl | Avoid overriding the BS, HT, LF, and CR keys
        0x01...0x07, 0x0b, 0x0c, 0x0e...0x1a, 0x1c...0x1f => KeyEvent{
            .code = KeyCode{ .char = input[0] + 96 },
            .modifiers = KeyModifiers{
                .control = true,
            },
        },
        else => null,
    };
    if (result) |_| return result;
    // Fn Key
    if (fn_lookup.get(input)) |fn_key| return fn_key;
    // Single charatcter input
    if (input.len == 1) return KeyEvent{
        .code = KeyCode{ .char = input[0] },
        .modifiers = KeyModifiers{ .shift = ascii.isUpper(input[0]) },
    };

    return null;
}

const LookupEntry = struct { []const u8, KeyEvent };
const fn_lookup = blk: {
    var table: []const LookupEntry = &.{};

    var fn_key = 0;
    for (10..35) |fn_code| {
        if (fn_code == 16 or fn_code == 22 or fn_code == 27 or fn_code == 30) {
            continue;
        }
        const code_string = std.fmt.comptimePrint("{d}", .{fn_code});
        table = table ++ .{
            .{ "\x1b[" ++ code_string ++ "~", KeyEvent{ .code = KeyCode{ .f = fn_key } } },
        };
        fn_key += 1;
    }
    table = table ++ .{
        .{ "\x1bOP", KeyEvent{ .code = KeyCode{ .f = 1 } } },
        .{ "\x1bOQ", KeyEvent{ .code = KeyCode{ .f = 2 } } },
        .{ "\x1bOR", KeyEvent{ .code = KeyCode{ .f = 3 } } },
        .{ "\x1bOS", KeyEvent{ .code = KeyCode{ .f = 4 } } },
    };

    break :blk std.ComptimeStringMap(KeyEvent, table);
};

const stdin = io.getStdIn().reader();
var stdin_br = io.bufferedReader(stdin);
/// This call blocks if raw mode is set to blocking and polls otherwise.
pub fn read() !?Event {
    var buffer: [8]u8 = undefined;
    const length = try stdin_br.reader().readAll(&buffer);
    if (length == 0) return null;
    const input = buffer[0..length];
    if (lookup(input)) |key_event| {
        return Event{
            .key = key_event,
        };
    } else return null;
}
