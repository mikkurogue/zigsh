const std = @import("std");
const Command = @import("command.zig");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const empty_config = .{};

pub const Prompt = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn prompt(self: *Self) !void {
        var buffer: [1024]u8 = undefined;

        while (true) {
            const path = try std.fs.cwd().realpathAlloc(self.allocator, ".");
            defer self.allocator.free(path);

            var cmd_runner = try Command.Command.init(self.allocator, path);

            try stdout.print("$ {s} ", .{path});
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
