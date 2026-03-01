const std = @import("std");
const Command = @import("command.zig").Command;
const Config = @import("config.zig").Config;
const Allocator = std.mem.Allocator;
const Color = @import("./lib/color.zig");

pub const Prompt = struct {
    const Self = @This();
    allocator: Allocator,
    sys_icon: ?[]const u8,
    user_color: Color.Color,
    path_color: Color.Color,
    prompt_icon: []const u8,
    prompt_color: Color.Color,

    pub fn init(allocator: Allocator, cfg: Config) Self {
        return .{
            .allocator = allocator,
            .sys_icon = cfg.sys_icon,
            .user_color = Color.Color.parse(cfg.user_color) orelse .{ .named = .blue },
            .path_color = Color.Color.parse(cfg.path_color) orelse .{ .named = .green },
            .prompt_icon = cfg.prompt_icon,
            .prompt_color = Color.Color.parse(cfg.prompt_color) orelse .{ .named = .yellow },
        };
    }

    pub fn draw_prompt(self: *Self) !void {
        var hostname_buffer: [64]u8 = undefined;

        // Buffers for the new Writer/Reader API
        var stdout_buffer: [4096]u8 = undefined;
        var stdin_buffer: [4096]u8 = undefined;

        // Color ANSI buffers
        var user_color_buf: [32]u8 = undefined;
        var path_color_buf: [32]u8 = undefined;
        var prompt_color_buf: [32]u8 = undefined;

        const user_ansi = self.user_color.toAnsi(&user_color_buf);
        const path_ansi = self.path_color.toAnsi(&path_color_buf);
        const prompt_ansi = self.prompt_color.toAnsi(&prompt_color_buf);

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

            // Print sys_icon at the beginning if set
            if (self.sys_icon) |icon| {
                try stdout_writer.interface.print("{s} ", .{icon});
            }

            try stdout_writer.interface.print("{s}{s}@{s}: {s}{s}{s} {s}{s}{s} ", .{
                user_ansi,
                usr,
                hostname,
                path_ansi,
                display_path,
                Color.clear_color,
                prompt_ansi,
                self.prompt_icon,
                Color.clear_color,
            });
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
