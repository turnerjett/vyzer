const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const io = std.io;
const testing = std.testing;
const test_log = std.log.scoped(.testing);

pub const command = @import("command.zig");
pub const event = @import("event.zig");

const stdin = io.getStdIn();

/// Enabling raw mode stops any processing for the input and output of the terminal.
/// Features such as echoing input characters, line buffering, and special character processing are disabled.
///
/// [Reference used](https://man7.org/linux/man-pages/man3/termios.3.html)
pub const RawMode = struct {
    /// Configuration to be passed to the enable function.
    pub const Config = struct {
        /// If set to true, the event.read() function will block until an event is triggered.
        blocking: bool = false,
        /// Time (in milliseconds) between polling for input. The value must never exceed 25,500 (25.5 seconds)
        /// due to termios requiring this value to fit into a byte representing tenths of a second.
        timeout: u16 = 0,
    };

    /// Enable raw mode.
    /// This will save the current terminal mode and restore it when disabling raw mode.
    pub fn enable(config: Config) !void {
        switch (builtin.target.os.tag) {
            .linux, .macos, .freebsd => {
                try enablePosix(config);
            },
            else => {
                @panic("OS is not supported by this library");
            },
        }
    }

    var original_termios: posix.termios = undefined;
    fn enablePosix(config: Config) !void {
        original_termios = try posix.tcgetattr(stdin.handle);
        const termios = posix.termios{
            .ispeed = posix.speed_t.B9600,
            .ospeed = posix.speed_t.B9600,
            .iflag = posix.tc_iflag_t{},
            .oflag = posix.tc_oflag_t{},
            .cflag = posix.tc_cflag_t{
                .CSIZE = .CS8,
                .CREAD = true,
            },
            .lflag = posix.tc_lflag_t{},
            .cc = blk: {
                var cc: [posix.NCCS]u8 = undefined;
                cc[@intFromEnum(posix.V.MIN)] = if (config.blocking) 1 else 0;
                cc[@intFromEnum(posix.V.TIME)] = @intCast(config.timeout / 100);
                break :blk cc;
            },
        };
        try posix.tcsetattr(stdin.handle, posix.TCSA.FLUSH, termios);
    }

    /// Disables raw mode, restoring the original termios configuration.
    pub fn disable() !void {
        switch (builtin.target.os.tag) {
            .linux, .macos, .freebsd => {
                try disablePosix();
            },
            else => {
                @panic("OS is not supported by this library");
            },
        }
    }

    fn disablePosix() !void {
        try posix.tcsetattr(stdin.handle, posix.TCSA.FLUSH, original_termios);
    }
};

pub const WindowSize = struct {
    const Self = @This();

    cols: u16,
    rows: u16,
    width: u16,
    height: u16,

    pub fn get() !Self {
        switch (builtin.target.os.tag) {
            .linux, .macos, .freebsd => {
                const winsize = try getPosix();
                return Self{
                    .cols = winsize.ws_col,
                    .rows = winsize.ws_row,
                    .width = winsize.ws_xpixel,
                    .height = winsize.ws_ypixel,
                };
            },
            else => {
                @panic("OS is not supported by this library");
            },
        }
    }

    fn getPosix() posix.UnexpectedError!posix.winsize {
        const stdout = io.getStdOut();
        const stdout_fd: posix.fd_t = stdout.handle;
        var winsize: posix.winsize = undefined;
        const result = posix.errno(std.c.ioctl(stdout_fd, posix.T.IOCGWINSZ, &winsize));
        switch (result) {
            .SUCCESS => {
                return winsize;
            },
            else => {
                std.log.err("ioctl failed with errno: {}", .{result});
                return posix.unexpectedErrno(result);
            },
        }
    }
};
