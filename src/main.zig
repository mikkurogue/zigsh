const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Prompt = @import("prompt.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var prompt = try Prompt.Prompt.init(allocator);

    try prompt.prompt();

    return 0;
}
