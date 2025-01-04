const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const Shell = @import("shell.zig");
const empty_config = .{};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(empty_config){};
    const allocator = gpa.allocator();

    var sh = try Shell.Shell.init(allocator);

    try sh.prompt();

    return 0;
}
