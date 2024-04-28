//! This module provides functions for modifying the terminal.
//!
//! Each function uses an ANSI escape code to execute a command. Some codes may be missing to aviod
//! crossplatform compatibility issues. If you need to use an ANSI code not provided by a function,
//! the "esc" function can be used to execute a raw command.
//!
//! [Reference used](https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797#escape)

const builtin = @import("builtin");
const std = @import("std");
const io = std.io;

inline fn fmtCmd(buffer_size: comptime_int, comptime fmt: []const u8, args: anytype) ![]u8 {
    var buffer: [buffer_size]u8 = undefined;
    const cmd = try std.fmt.bufPrint(&buffer, fmt, args);
    return cmd;
}

const stdout = io.getStdOut().writer();
const stdin = io.getStdIn().reader();

/// Used to send raw ANSI escape codes to stdout.
pub fn esc(code: []const u8) !void {
    _ = try stdout.print("\x1B{s}", .{code});
}

/// Commands for controlling the terminals alternative buffer.
pub const AltScreen = struct {
    /// Enables the alternative buffer.
    pub fn enter() !void {
        try esc("[?1049h");
    }
    /// Disables the alternative buffer.
    pub fn exit() !void {
        try esc("[?1049l");
    }
};

/// Commands for controlling the terminals cursor.
pub const Cursor = struct {
    /// Moves the cursor to the home position (0, 0).
    pub fn toHome() !void {
        try esc("[H");
    }

    /// Moves the cursor to the specified coordinates (x/column, y/row).
    pub fn to(x: u16, y: u16) !void {
        const cmd = try fmtCmd(16, "[{d};{d}H", .{ y, x });
        try esc(cmd);
    }

    /// Moves the cursor up from the current position by the amount specified.
    pub fn up(amount: u16) !void {
        const cmd = try fmtCmd(8, "[{d}A", .{amount});
        try esc(cmd);
    }

    /// Moves the cursor down from the current position by the amount specified.
    pub fn down(amount: u16) !void {
        const cmd = try fmtCmd(8, "[{d}B", .{amount});
        try esc(cmd);
    }

    /// Moves the cursor right from the current position by the amount specified.
    pub fn right(amount: u16) !void {
        const cmd = try fmtCmd(8, "[{d}C", .{amount});
        try esc(cmd);
    }

    /// Moves the cursor left from the current position by the amount specified.
    pub fn left(amount: u16) !void {
        const cmd = try fmtCmd(8, "[{d}D", .{amount});
        try esc(cmd);
    }

    /// Moves the cursor to the beginning of the next line and the specified amount of lines down.
    pub fn nextDown(amount: u16) !void {
        const cmd = try fmtCmd(8, "[{d}E", .{amount});
        try esc(cmd);
    }

    /// Moves the cursor to the beginning of the previous line and the specified amount of lines up.
    pub fn previousUp(amount: u16) !void {
        const cmd = try fmtCmd(8, "[{d}F", .{amount});
        try esc(cmd);
    }

    /// Moves the cursor to the specified column.
    pub fn toColumn(column: u16) !void {
        const cmd = try fmtCmd(8, "[{d}G", .{column});
        try esc(cmd);
    }

    const Position = struct {
        x: u16 = 0,
        y: u16 = 0,
    };

    /// Returns the current position of the cursor.
    pub fn getPosition() !Position {
        var stdin_br = io.bufferedReader(stdin);
        try esc("[6n");
        var buf: [16]u8 = undefined;
        const res = try stdin_br.reader().readUntilDelimiter(&buf, 'R');

        var position = Position{};
        var buffer: [8]u8 = undefined;
        var pos: usize = 0;
        for (res, 0..) |current_byte, i| {
            if (std.ascii.isDigit(current_byte)) {
                buffer[pos] = current_byte;
                pos += 1;
                if (i == res.len - 1) {
                    const value = try std.fmt.parseInt(u8, buffer[0..pos], 10);
                    position.x = value;
                    break;
                }
                continue;
            }
            if (current_byte == ';') {
                const value = try std.fmt.parseInt(u8, buffer[0..pos], 10);
                position.y = value;
                pos = 0;
            }
        }
        return position;
    }
};

/// This allows for pastes to be recieved as an event.
pub const Paste = struct {
    /// Enables (bracketed paste mode)[https://en.wikipedia.org/wiki/Bracketed-paste].
    pub fn enable() !void {
        try esc("[?2004h");
    }
    /// Disables (bracketed paste mode)[https://en.wikipedia.org/wiki/Bracketed-paste].
    pub fn disable() !void {
        try esc("[?2004l");
    }
};
