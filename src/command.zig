const std = @import("std");
const posix = std.posix;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const Dir = fs.Dir;
const assert = std.debug.assert;

const Builtin = enum {
    exit,
    echo,
    type,
    pwd,
    cd,
};

pub const Command = struct {
    allocator: Allocator,
    path: []u8,
    stdout_buffer: [4096]u8 = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator, path: []u8) !Self {
        return .{
            .allocator = allocator,
            .path = path,
        };
    }

    fn getStdoutWriter(self: *Self) std.fs.File.Writer {
        return std.fs.File.stdout().writer(&self.stdout_buffer);
    }

    pub fn run(self: *Self, cmd: []const u8) !void {
        try self.handle_input(cmd);
    }

    fn handle_input(self: *Self, input: []const u8) !void {
        assert(input.len != 0);

        var input_slices = std.mem.splitSequence(u8, input, " ");

        // initial command is the first full string in the split sequence
        const cmd = input_slices.first();
        // args are the rest of the items that come after first full string
        const args = input_slices.rest();
        // this checks if it is a shell builtin
        const shell_builtin = std.meta.stringToEnum(Builtin, cmd);

        if (shell_builtin) |built_in| {
            try self.builtin_handler(built_in, args);
        } else {
            try self.spawn_command_process(cmd, &input_slices);
        }
    }

    fn spawn_command_process(self: *Self, cmd: []const u8, input_slices: *const std.mem.SplitIterator(u8, .sequence)) !void {
        const path = try find_on_path(self.allocator, cmd);

        if (std.mem.startsWith(u8, cmd, "./")) {
            // TODO: Implement exec_from_zigsh(cmd, input_slices); method
            try self.exec_from_zigsh(cmd, input_slices);
            return;
        }

        if (path) |p| {
            defer self.allocator.free(p);
            // Use the new ArrayList API - initialize with empty and pass allocator to methods
            var arg_arr: std.ArrayList([]const u8) = .empty;
            defer arg_arr.deinit(self.allocator);

            // First argument should be the path that we want to go to
            try arg_arr.append(self.allocator, p);

            // now append the rest of the arguments
            var slices = input_slices.*;
            while (slices.next()) |arg| {
                try arg_arr.append(self.allocator, arg);
            }

            var child = std.process.Child.init(arg_arr.items, self.allocator);
            _ = try child.spawnAndWait();
        } else {
            var stdout_writer = self.getStdoutWriter();
            try stdout_writer.interface.print("{s}: Command not found\n", .{cmd});
            try stdout_writer.interface.flush();
        }
    }

    fn exec_from_zigsh(self: *Self, cmd: []const u8, input_slices: *const std.mem.SplitIterator(u8, .sequence)) !void {
        var arg_arr: std.ArrayList([]const u8) = .empty;
        defer arg_arr.deinit(self.allocator);

        try arg_arr.append(self.allocator, cmd);

        var slices = input_slices.*;
        while (slices.next()) |arg| {
            try arg_arr.append(self.allocator, arg);
        }

        var child = std.process.Child.init(arg_arr.items, self.allocator);
        _ = try child.spawnAndWait();
    }

    fn builtin_handler(self: *Self, T: Builtin, args: []const u8) !void {
        // this is not the same path as we set in the Prompt, hence we can not use it
        // this is the current path the shell is in
        // hence why we have to manually de-alloc it
        const path = try fs.cwd().realpathAlloc(self.allocator, ".");
        defer self.allocator.free(path);

        var stdout_writer = self.getStdoutWriter();

        switch (T) {
            Builtin.exit => std.process.exit(0),
            Builtin.echo => {
                try stdout_writer.interface.print("{s}\n", .{args});
                try stdout_writer.interface.flush();
            },
            Builtin.type => try self.handle_type(args),
            Builtin.pwd => {
                try stdout_writer.interface.print("{s}\n", .{path});
                try stdout_writer.interface.flush();
            },
            Builtin.cd => try self.handle_ch_dir(args),
        }
    }

    fn handle_type(self: *Self, args: []const u8) !void {
        var stdout_writer = self.getStdoutWriter();
        const args_type = std.meta.stringToEnum(Builtin, args);
        if (args_type) |t| {
            try stdout_writer.interface.print("{s} is a shell builtin\n", .{@tagName(t)});
        } else {
            try stdout_writer.interface.print("{s}: not found\n", .{args});
        }
        try stdout_writer.interface.flush();
    }

    fn handle_ch_dir(self: *Self, args: []const u8) !void {
        if (std.mem.eql(u8, args, "~") or std.mem.eql(u8, args, "$HOME") or args.len == 0 or std.mem.eql(u8, args, " ")) {
            try self.handle_cd_home();
            return;
        }

        // handle relative paths
        if (std.mem.startsWith(u8, args, "../")) {
            try self.handle_relative_ch_dir(args);
            return;
        }

        if (std.posix.chdir(args)) {} else |_| {
            var stdout_writer = self.getStdoutWriter();
            try stdout_writer.interface.print("cd: {s}: No such file or directory\n", .{args});
            try stdout_writer.interface.flush();
        }
    }

    fn handle_cd_home(self: *Self) !void {
        _ = self;
        const home = posix.getenv("HOME") orelse unreachable;
        if (posix.chdir(home)) {} else |_| {
            return error.NoHomeEnvSet;
        }
    }

    fn handle_relative_ch_dir(self: *Self, args: []const u8) !void {
        const cd_to = try fs.cwd().realpathAlloc(self.allocator, args);
        defer self.allocator.free(cd_to);

        if (posix.chdir(cd_to)) {} else |_| {
            var stdout_writer = self.getStdoutWriter();
            try stdout_writer.interface.print("cd: {s}: No such file or directory\n", .{cd_to});
            try stdout_writer.interface.flush();
        }
    }
};

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
