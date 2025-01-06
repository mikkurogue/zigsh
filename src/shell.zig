const std = @import("std");
const Command = @import("command.zig").Command;
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const empty_config = .{};

pub const Shell = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn prompt(self: *Self) !void {
        var buffer: [1024]u8 = undefined;
        var hostname_buffer: [64]u8 = undefined;

        const usr = std.posix.getenv("USER") orelse unreachable;

        const hostname = try std.posix.gethostname(&hostname_buffer);

        while (true) {
            const path = try std.fs.cwd().realpathAlloc(self.allocator, ".");
            defer self.allocator.free(path);

            const home = std.posix.getenv("HOME") orelse unreachable;

            var display_path: []const u8 = path;
            if (home.len > 0 and std.mem.startsWith(u8, path, home)) {
                // slice off the home directory prefix and prepend "~" because it looks cooler
                display_path = try std.mem.concat(self.allocator, u8, &[_][]const u8{ "~", path[home.len..] });
            }
            defer self.allocator.free(display_path);
            var cmd_runner = try Command.init(self.allocator, path);

            try stdout.print("{s}{s}@{s}: {s}{s}{s} > ", .{ blue, hostname, usr, green, display_path, clear_color });
            if (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
                const cmd = line;
                if (cmd.len != 0) {
                    // run the command
                    try cmd_runner.run(cmd);
                } else {
                    try stdout.print("\n", empty_config);
                }
            }
        }
    }
};

/// ANSI escape colours - this needs to be "expanded" upon
const clear_color = "\x1b[0m";
const red = "\x1b[31m";
const green = "\x1b[32m";
const blue = "\x1b[34m";
