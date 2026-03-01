const std = @import("std");
const Command = @import("command.zig").Command;
const Prompt = @import("prompt.zig").Prompt;
const Config = @import("config.zig").Config;

const Allocator = std.mem.Allocator;

pub const Shell = struct {
    allocator: Allocator,
    cfg: Config,

    const Self = @This();

    pub fn init(allocator: Allocator, cfg: Config) Self {
        return .{
            .allocator = allocator,
            .cfg = cfg,
        };
    }

    pub fn prompt(self: *Self) !void {
        var shell_prompt = Prompt.init(self.allocator, self.cfg);

        try shell_prompt.draw_prompt();
    }
};
