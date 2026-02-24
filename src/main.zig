const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const Shell = @import("shell.zig").Shell;
const empty_config = .{};

pub fn main() !u8 {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var sh = try Shell.init(allocator);

    try sh.prompt();

    return 0;
}
