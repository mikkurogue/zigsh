const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Builtins for the commands that are common syscommands
const Builtin = enum {
    exit,
    echo,
    type,
    pwd,
    cd,
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try repl(allocator);

    return 0;
}

/// REPL function wrapper
/// This is the main shell loop for the application
fn repl(allocator: std.mem.Allocator) !void {
    var buffer: [1024]u8 = undefined;

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
}

/// Basic handler to handle input commands
fn builtin_handler(T: Builtin, args: []const u8) !void {
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

/// Handle the cd command.
fn handle_ch_dir(args: []const u8) !void {
    if (std.mem.eql(u8, args, "~") or std.mem.eql(u8, args, "$HOME") or args.len == 0 or std.mem.eql(u8, args, " ")) {
        try handle_ch_home();
        return;
    }

    // TODO: Handle executing executables like shell scripts, .AppImage etc.
    // Need to figure out best way to spawn a process from it

    // handle relative paths
    if (std.mem.startsWith(u8, args, "../")) {
        try handle_relative_ch_dir(args);
        return;
    }

    if (std.posix.chdir(args)) {} else |_| {
        try stdout.print("cd: {s}: No such file or directory\n", .{args});
    }
}

/// Handle the cd command but for relative pathing
fn handle_relative_ch_dir(args: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cd_to = try std.fs.cwd().realpathAlloc(allocator, args);
    defer allocator.free(cd_to);

    if (std.posix.chdir(cd_to)) {} else |_| {
        try stdout.print("cd: {s}: No such file or directory\n", .{cd_to});
    }
}

/// Handle the cd command to cd back to home dir
fn handle_ch_home() !void {
    const home = std.posix.getenv("HOME") orelse unreachable;
    if (std.posix.chdir(home)) {} else |_| {
        return error.NoHomeEnvSet;
    }
}

/// check if a command is a builtin command in this shell - i think this is useless but
/// lets keep it just for fun and stringToEnum reference for learning
fn handle_type(args: []const u8) !void {
    const args_type = std.meta.stringToEnum(Builtin, args);
    if (args_type) |@"type"| {
        try stdout.print("{s} is a shell builtin\n", .{@tagName(@"type")});
    } else {
        try stdout.print("{s}: not found\n", .{args});
    }
}

/// Handle user input
/// If  command is not a built in, then execute a new process.
fn handle_input(allocator: Allocator, input: []const u8) !void {
    assert(input.len != 0);

    var input_slices = std.mem.splitSequence(u8, input, " ");

    const cmd = input_slices.first();
    const args = input_slices.rest();
    const shell_builtin = std.meta.stringToEnum(Builtin, cmd);

    if (shell_builtin) |built_in| {
        try builtin_handler(built_in, args);
    } else {
        try spawn_command_process(allocator, cmd, &input_slices);
    }
}

/// Spawn the process for the inputted command.
/// This spawns the not-builtins
fn spawn_command_process(allocator: std.mem.Allocator, cmd: []const u8, input_slices: anytype) !void {
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

/// Find a command on the path, for instance something like "ls" or "cat"
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
