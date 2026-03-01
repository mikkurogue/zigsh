const std = @import("std");

/// Standard ANSI colors
pub const NamedColor = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    /// Get the ANSI code for this named color
    pub fn toAnsiCode(self: NamedColor) u8 {
        return switch (self) {
            .black => 30,
            .red => 31,
            .green => 32,
            .yellow => 33,
            .blue => 34,
            .magenta => 35,
            .cyan => 36,
            .white => 37,
        };
    }
};

/// RGB color for 24-bit true color support
pub const RgbColor = struct {
    r: u8,
    g: u8,
    b: u8,
};

/// Color that can be either a named ANSI color or an RGB hex color
pub const Color = union(enum) {
    named: NamedColor,
    rgb: RgbColor,

    /// Parse a color string - either a name like "red" or hex like "#ff0000"
    pub fn parse(str: []const u8) ?Color {
        if (str.len == 0) return null;

        // Check for hex color
        if (str[0] == '#' and str.len == 7) {
            const r = std.fmt.parseInt(u8, str[1..3], 16) catch return null;
            const g = std.fmt.parseInt(u8, str[3..5], 16) catch return null;
            const b = std.fmt.parseInt(u8, str[5..7], 16) catch return null;
            return .{ .rgb = .{ .r = r, .g = g, .b = b } };
        }

        // Check for named color
        const named = std.meta.stringToEnum(NamedColor, str) orelse return null;
        return .{ .named = named };
    }

    /// Write the ANSI escape sequence for this color to a buffer
    /// Returns the slice of the buffer that was written
    pub fn toAnsi(self: Color, buf: []u8) []const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        switch (self) {
            .named => |named| {
                writer.print("\x1b[{d}m", .{named.toAnsiCode()}) catch return "";
            },
            .rgb => |rgb| {
                // 24-bit true color: \x1b[38;2;R;G;Bm
                writer.print("\x1b[38;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }) catch return "";
            },
        }

        return fbs.getWritten();
    }
};

/// ANSI reset sequence
pub const clear_color = "\x1b[0m";
