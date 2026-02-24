const std = @import("std");
const Command = @import("command.zig").Command;

const Allocator = std.mem.Allocator;

pub const Shell = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn prompt(self: *Self) !void {
        var hostname_buffer: [64]u8 = undefined;

        // Buffers for the new Writer/Reader API
        var stdout_buffer: [4096]u8 = undefined;
        var stdin_buffer: [4096]u8 = undefined;

        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);

        const usr = std.posix.getenv("USER") orelse unreachable;
        const hostname = try std.posix.gethostname(&hostname_buffer);

        while (true) {
            const path = try std.fs.cwd().realpathAlloc(self.allocator, ".");
            defer self.allocator.free(path);

            const home = std.posix.getenv("HOME") orelse unreachable;

            var display_path: []const u8 = path;
            var allocated_display_path = false;
            if (home.len > 0 and std.mem.startsWith(u8, path, home)) {
                // slice off the home directory prefix and prepend "~" because it looks cooler
                display_path = try std.mem.concat(self.allocator, u8, &[_][]const u8{ "~", path[home.len..] });
                allocated_display_path = true;
            }
            defer if (allocated_display_path) self.allocator.free(display_path);

            var cmd_runner = try Command.init(self.allocator, path);

            try stdout_writer.interface.print("{s}{s}@{s}: {s}{s}{s} > ", .{ blue, usr, hostname, green, display_path, clear_color });
            try stdout_writer.interface.flush();

            // Read a line using the new Reader API
            // takeDelimiterExclusive returns the line without the newline character
            // but does NOT consume the delimiter, so we need to toss it manually
            const line = stdin_reader.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
                error.EndOfStream => break, // EOF, exit the shell
                else => |e| return e,
            };
            // Skip past the newline delimiter
            stdin_reader.interface.toss(1);

            if (line.len != 0) {
                // run the command
                try cmd_runner.run(line);
            } else {
                try stdout_writer.interface.print("\n", .{});
                try stdout_writer.interface.flush();
            }
        }
    }
};

/// ANSI escape colours - this needs to be "expanded" upon
const clear_color = "\x1b[0m";
const red = "\x1b[31m";
const green = "\x1b[32m";
const blue = "\x1b[34m";
