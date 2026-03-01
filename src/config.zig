const std = @import("std");
const toml = @import("toml");

pub const Config = struct {
    sys_icon: ?[]const u8 = null,
    user_color: []const u8,
    host_color: []const u8,
    path_color: []const u8,
    prompt_icon: []const u8,
    prompt_color: []const u8,
    show_toolchain: bool,
};

pub fn load_config(allocator: std.mem.Allocator) !Config {
    const config_path = try get_config_path(allocator);
    defer allocator.free(config_path);

    const file = std.fs.openFileAbsolute(config_path, .{}) catch {
        return default_config();
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return default_config();
    };
    defer allocator.free(content);

    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    var result = parser.parseString(content) catch |err| {
        std.debug.print("Could not parse config file: {any}\n", .{err});
        return default_config();
    };
    defer result.deinit();

    const cfg = Config{
        .sys_icon = if (result.value.sys_icon) |icon| try allocator.dupe(u8, icon) else null,
        .user_color = try allocator.dupe(u8, result.value.user_color),
        .host_color = try allocator.dupe(u8, result.value.host_color),
        .path_color = try allocator.dupe(u8, result.value.path_color),
        .prompt_icon = try allocator.dupe(u8, result.value.prompt_icon),
        .prompt_color = try allocator.dupe(u8, result.value.prompt_color),
        .show_toolchain = result.value.show_toolchain,
    };

    std.debug.print("Loaded config: {any}\n", .{cfg});

    return cfg;
}

fn get_config_path(allocator: std.mem.Allocator) ![]const u8 {
    const home = std.posix.getenv("HOME") orelse unreachable;
    return try std.mem.concat(allocator, u8, &[_][]const u8{ home, "/.config/zigsh/config.toml" });
}

fn default_config() Config {
    return Config{
        .sys_icon = null,
        .user_color = "#5555ff",
        .host_color = "#5555ff",
        .path_color = "#55ff55",
        .prompt_icon = "❯",
        .prompt_color = "#ffff55",
        .show_toolchain = true,
    };
}
