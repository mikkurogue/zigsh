const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Builtin = enum {
    exit,
    echo,
    type,
    pwd,
    cd,
};

pub fn main() !u8 {
    // REPL - main loop

    var buffer: [1024]u8 = undefined;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    while (true) {
        const path = try std.fs.cwd().realpathAlloc(allocator, ".");
        defer allocator.free(path);

        try stdout.print("$ {s} ~ ", .{path});

        if (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            const cmd = line;

            if (cmd.len != 0) {
                try handle_input(allocator, cmd);
            } else {
                try stdout.print("\n", .{});
            }
        }
    }

    return 0;
}

fn handler(T: Builtin, args: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(path);

    switch (T) {
        Builtin.exit => std.process.exit(0),
        Builtin.echo => try stdout.print("{s}\n", .{args}),
        Builtin.type => try handle_type(args),
        Builtin.pwd => try stdout.print("{s}\n", .{path}),
        Builtin.cd => try handle_ch_dir(args),
    }
}

fn handle_ch_dir(args: []const u8) !void {
    if (std.mem.eql(u8, args, "~") or std.mem.eql(u8, args, "$HOME")) {
        const home = std.posix.getenv("HOME") orelse unreachable;
        if (std.posix.chdir(home)) {} else |_| {
            return error.NoHomeEnvSet;
        }
        return;
    }

    // handle relative paths
    if (std.mem.startsWith(u8, args, "./") or std.mem.startsWith(u8, args, "../")) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();

        const cd_to = try std.fs.cwd().realpathAlloc(allocator, args);
        defer allocator.free(cd_to);

        if (std.posix.chdir(cd_to)) {} else |_| {
            try stdout.print("cd: {s}: No such file or directory\n", .{cd_to});
        }

        return;
    }

    if (std.posix.chdir(args)) {} else |_| {
        try stdout.print("cd: {s}: No such file or directory\n", .{args});
    }
}

fn handle_type(args: []const u8) !void {
    const args_type = std.meta.stringToEnum(Builtin, args);
    if (args_type) |@"type"| {
        try stdout.print("{s} is a shell builtin\n", .{@tagName(@"type")});
    } else {
        try stdout.print("{s}: not found\n", .{args});
    }
}

fn handle_input(allocator: Allocator, input: []const u8) !void {
    assert(input.len != 0);

    var input_slices = std.mem.splitSequence(u8, input, " ");

    const cmd = input_slices.first();
    const args = input_slices.rest();
    const shell_builtin = std.meta.stringToEnum(Builtin, cmd);

    if (shell_builtin) |built_in| {
        try handler(built_in, args);
    } else {
        const path = try find_on_path(allocator, cmd);
        if (path) |p| {
            defer allocator.free(p);

            var arg_arr = std.ArrayList([]const u8).init(std.heap.page_allocator);
            defer arg_arr.deinit();

            try arg_arr.append(p);

            while (input_slices.next()) |arg| {
                try arg_arr.append(arg);
            }

            var child = std.process.Child.init(arg_arr.items, std.heap.page_allocator);
            _ = try child.spawnAndWait();
        } else {
            try stdout.print("{s}: command not found\n", .{cmd});
        }
    }
}

fn find_on_path(allocator: Allocator, name: []const u8) !?[]const u8 {
    const path = std.posix.getenv("PATH") orelse "";

    var iter = std.mem.tokenizeScalar(u8, path, ':');

    while (iter.next()) |dir_name| {
        const joined = try std.fs.path.join(allocator, &[_][]const u8{ dir_name, name });

        if (std.fs.cwd().access(joined, std.fs.File.OpenFlags{})) {
            return joined;
        } else |_| {}

        allocator.free(joined);
    }

    return null;
}
