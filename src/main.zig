const std = @import("std");
const config = @import("config.zig");
const Allocator = std.mem.Allocator;
const Shell = @import("shell.zig").Shell;

pub fn main() !u8 {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const cfg = try config.load_config(allocator);

    var sh = Shell.init(allocator, cfg);

    try sh.prompt();

    return 0;
}
