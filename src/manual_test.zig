const std = @import("std");
const time = std.time;
const lib = @import("root.zig");
const command = lib.command;
const event = lib.event;

pub fn main() !void {
    try @"test key events"();
}

fn @"test key events"() !void {
    try lib.RawMode.enable(.{});
    try command.AltScreen.enter();
    while (true) {
        const input = (event.read() catch break) orelse {
            try command.Cursor.toColumn(1);
            continue;
        };
        switch (input) {
            .key => |key_event| {
                std.debug.print("Raw key Event: {}\n", .{key_event});
                try command.Cursor.toColumn(1);
                switch (key_event.code) {
                    .char => |byte| {
                        if (byte == 'q') break;
                        std.debug.print("Character input: {c}\n", .{byte});
                        try command.Cursor.toColumn(1);
                    },
                    else => {},
                }
            },
        }
    }

    try command.AltScreen.exit();
    try lib.RawMode.disable();
}
